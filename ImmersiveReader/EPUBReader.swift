import Foundation
import SSZipArchive


class EPUBReader {
    private var contentPath: String?
    private var tempDirectory: URL?
    private var bookTitle: String?
    private var bookAuthor: String?
    private var chapters: [Book.Chapter] = []
    
    func readEPUBBook(at fileURL: URL) throws -> Book {
        // First, extract book metadata and content
        if !open(epubPath: fileURL.path) {
            throw FileReader.FileError.readError
        }
        
        // Get table of contents
        guard let toc = getTableOfContents() else {
            throw FileReader.FileError.readError
        }
        
        // Process each chapter
        for (_, href) in toc {
            if let content = getChapterContent(href: href) {
                let title = extractTitle(from: content) ?? "Chapter \(chapters.count + 1)"
                let chapter = Book.Chapter(
                    title: title,
                    content: stripHTML(from: content),
                    htmlContent: content
                )
                chapters.append(chapter)
            }
        }
        
        // If no title was found, use the filename
        if bookTitle == nil {
            bookTitle = fileURL.deletingPathExtension().lastPathComponent
                .replacingOccurrences(of: "_", with: " ")
        }
        
        // Create the book
        let book = Book(
            title: bookTitle ?? "Unknown Title",
            author: bookAuthor ?? "Unknown Author",
            chapters: chapters,
            coverImageData: nil
        )
        
        // Clean up
        close()
        
        return book
    }
    
    private func open(epubPath: String) -> Bool {
        // Create a temporary directory for extraction
        tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        
        do {
            try FileManager.default.createDirectory(at: tempDirectory!, withIntermediateDirectories: true)
            
            // Extract EPUB (which is a zip file)
            let success = SSZipArchive.unzipFile(atPath: epubPath, toDestination: tempDirectory!.path)
            if success {
                // Parse container.xml to find content path
                return parseContainer()
            }
            return false
        } catch {
            print("Error creating temp directory: \(error)")
            return false
        }
    }
    
    private func parseContainer() -> Bool {
        guard let tempDir = tempDirectory else { return false }
        
        let containerPath = tempDir.appendingPathComponent("META-INF/container.xml").path
        
        guard FileManager.default.fileExists(atPath: containerPath),
              let containerData = try? Data(contentsOf: URL(fileURLWithPath: containerPath)) else {
            return false
        }
        
        // Simple XML parsing without XMLDocument (which is macOS only)
        let containerString = String(data: containerData, encoding: .utf8) ?? ""
        if let fullPathRange = containerString.range(of: "full-path=\""),
           let endQuoteRange = containerString[fullPathRange.upperBound...].range(of: "\"") {
            let fullPath = String(containerString[fullPathRange.upperBound..<endQuoteRange.lowerBound])
            contentPath = tempDir.appendingPathComponent(fullPath).path
            return true
        }
        
        return false
    }
    
    private func getTableOfContents() -> [String: String]? {
        guard let contentPath = contentPath,
              FileManager.default.fileExists(atPath: contentPath),
              let contentData = try? Data(contentsOf: URL(fileURLWithPath: contentPath)) else {
            return nil
        }
        
        // Simple parsing of OPF file
        let contentString = String(data: contentData, encoding: .utf8) ?? ""
        var toc: [String: String] = [:]
        
        // Extract metadata
        extractMetadata(from: contentString)
        
        // Extract spine and manifest items
        var itemMap: [String: String] = [:]
        
        // Find manifest items
        let itemPattern = "<item[^>]+id=\"([^\"]+)\"[^>]+href=\"([^\"]+)\""
        if let regex = try? NSRegularExpression(pattern: itemPattern, options: []) {
            let matches = regex.matches(in: contentString, options: [], range: NSRange(contentString.startIndex..., in: contentString))
            
            for match in matches {
                if let idRange = Range(match.range(at: 1), in: contentString),
                   let hrefRange = Range(match.range(at: 2), in: contentString) {
                    let id = String(contentString[idRange])
                    let href = String(contentString[hrefRange])
                    itemMap[id] = href
                }
            }
        }
        
        // Find spine items
        let spinePattern = "<itemref[^>]+idref=\"([^\"]+)\""
        if let regex = try? NSRegularExpression(pattern: spinePattern, options: []) {
            let matches = regex.matches(in: contentString, options: [], range: NSRange(contentString.startIndex..., in: contentString))
            
            for match in matches {
                if let idrefRange = Range(match.range(at: 1), in: contentString) {
                    let idref = String(contentString[idrefRange])
                    if let href = itemMap[idref] {
                        toc[idref] = href
                    }
                }
            }
        }
        
        return toc
    }
    
    private func extractMetadata(from opfContent: String) {
        // Extract title
        if let titleStartRange = opfContent.range(of: "<dc:title>"),
           let titleEndRange = opfContent[titleStartRange.upperBound...].range(of: "</dc:title>") {
            bookTitle = String(opfContent[titleStartRange.upperBound..<titleEndRange.lowerBound])
        }
        
        // Extract author
        if let creatorStartRange = opfContent.range(of: "<dc:creator"),
           let creatorContentStart = opfContent[creatorStartRange.upperBound...].range(of: ">"),
           let creatorEndRange = opfContent[creatorContentStart.upperBound...].range(of: "</dc:creator>") {
            bookAuthor = String(opfContent[creatorContentStart.upperBound..<creatorEndRange.lowerBound])
        }
    }
    
    private func getChapterContent(href: String) -> String? {
        guard let contentPath = contentPath else { return nil }
        
        // Get the content directory
        let contentURL = URL(fileURLWithPath: contentPath)
        let contentDir = contentURL.deletingLastPathComponent()
        let chapterPath = contentDir.appendingPathComponent(href).path
        
        do {
            if FileManager.default.fileExists(atPath: chapterPath) {
                let chapterHTML = try String(contentsOfFile: chapterPath, encoding: .utf8)
                return chapterHTML
            }
            return nil
        } catch {
            print("Error reading chapter: \(error)")
            return nil
        }
    }
    
    private func extractTitle(from htmlContent: String) -> String? {
        // Try to extract title from HTML content
        if let titleStartRange = htmlContent.range(of: "<title>"),
           let titleEndRange = htmlContent[titleStartRange.upperBound...].range(of: "</title>") {
            return String(htmlContent[titleStartRange.upperBound..<titleEndRange.lowerBound])
        }
        
        // Try h1 if title is not found
        if let h1StartRange = htmlContent.range(of: "<h1[^>]*>", options: .regularExpression),
           let h1ContentStart = htmlContent[h1StartRange.upperBound...].range(of: ">"),
           let h1EndRange = htmlContent[h1ContentStart.upperBound...].range(of: "</h1>") {
            return String(htmlContent[h1ContentStart.upperBound..<h1EndRange.lowerBound])
        }
        
        return nil
    }
    
    private func stripHTML(from htmlContent: String) -> String {
        // Very basic HTML stripping - for production use a more robust solution
        var content = htmlContent
        // Remove HTML tags
        while let tagStartRange = content.range(of: "<[^>]+>", options: .regularExpression) {
            content.removeSubrange(tagStartRange)
        }
        
        // Convert HTML entities
        content = content.replacingOccurrences(of: "&nbsp;", with: " ")
        content = content.replacingOccurrences(of: "&lt;", with: "<")
        content = content.replacingOccurrences(of: "&gt;", with: ">")
        content = content.replacingOccurrences(of: "&amp;", with: "&")
        
        return content
    }
    
    func close() {
        if let tempDir = tempDirectory {
            try? FileManager.default.removeItem(at: tempDir)
            tempDirectory = nil
        }
    }
} 
