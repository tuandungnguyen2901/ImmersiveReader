import Foundation

class FileReader {
    enum FileError: Error {
        case fileNotFound
        case readError
        case unsupportedFileFormat
    }
    
    func readFrom(fileURL: URL) throws -> Book {
        // Check if file exists
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("File not found at path: \(fileURL.path)")
            throw FileError.fileNotFound
        }
        
        let fileExtension = fileURL.pathExtension.lowercased()
        
        // Handle different file types
        switch fileExtension {
        case "txt":
            return try readTextFile(from: fileURL)
        case "epub":
            // Use our new EPUBReader for EPUB files
            if isEPUBZipArchiveAvailable() {
                return try readEPUBFile(from: fileURL)
            } else {
                // Fallback if ZIP library is not available
                return try createPlaceholderBookFromEPUB(fileURL)
            }
        default:
            // Extract title from filename for unsupported files
            let fileName = fileURL.deletingPathExtension().lastPathComponent
            return Book(
                title: fileName,
                author: "Unknown",
                chapters: [Book.Chapter(
                    title: "Preview",
                    content: "This file format is not fully supported yet.",
                    htmlContent: "<html><body><h1>\(fileName)</h1><p>This file format is not fully supported yet.</p></body></html>"
                )],
                coverImageData: nil
            )
        }
    }
    
    private func isEPUBZipArchiveAvailable() -> Bool {
        // Check if ZipArchive is available
        return NSClassFromString("SSZipArchive") != nil
    }
    
    private func readEPUBFile(from fileURL: URL) throws -> Book {
        // For testing - create a placeholder book with multiple chapters
        let fileName = fileURL.deletingPathExtension().lastPathComponent
            .replacingOccurrences(of: "_", with: " ")
        
        // Create multiple sample chapters
        var chapters: [Book.Chapter] = []
        for i in 1...5 {
            let chapterTitle = "Chapter \(i)"
            let chapterContent = "This is sample content for chapter \(i) of the EPUB book.\n\nMore paragraph text would appear here in a real EPUB file."
            let htmlContent = "<html><body><h1>\(chapterTitle)</h1><p>\(chapterContent.replacingOccurrences(of: "\n\n", with: "</p><p>"))</p></body></html>"
            
            let chapter = Book.Chapter(title: chapterTitle, content: chapterContent, htmlContent: htmlContent)
            chapters.append(chapter)
        }
        
        return Book(
            title: fileName,
            author: "EPUB Book",
            chapters: chapters,
            coverImageData: nil
        )
    }
    
    private func readTextFile(from fileURL: URL) throws -> Book {
        do {
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            print("Successfully read text file from: \(fileURL.path)")
            
            let lines = content.components(separatedBy: .newlines)
            
            // Assume first line is title, second is author (if they exist)
            let title = lines.count > 0 ? lines[0] : fileURL.deletingPathExtension().lastPathComponent
            let author = lines.count > 1 ? lines[1] : "Unknown"
            
            // The rest is content
            let contentStart = min(2, lines.count)
            let chapterContent = lines.count > contentStart ? lines[contentStart...].joined(separator: "\n") : ""
            
            let htmlContent = "<html><body><h1>\(title)</h1><p>\(chapterContent.replacingOccurrences(of: "\n\n", with: "</p><p>"))</p></body></html>"
            
            let chapter = Book.Chapter(title: "Chapter 1", content: chapterContent, htmlContent: htmlContent)
            
            return Book(title: title, author: author, chapters: [chapter], coverImageData: nil)
        } catch {
            print("Error reading text file at \(fileURL.path): \(error)")
            throw FileError.readError
        }
    }
    
    private func createPlaceholderBookFromEPUB(_ fileURL: URL) throws -> Book {
        // For EPUB files, extract basic metadata from the file name
        let fileName = fileURL.deletingPathExtension().lastPathComponent
            .replacingOccurrences(of: "_", with: " ")
        
        // Create sample chapters for now
        let sampleContent = "This is a preview of the EPUB file.\n\nFull EPUB parsing is not implemented yet."
        let htmlContent = "<html><body><h1>\(fileName)</h1><p>This is a preview of the EPUB file.</p><p>Full EPUB parsing is not implemented yet.</p></body></html>"
        
        let chapter = Book.Chapter(
            title: "Preview",
            content: sampleContent,
            htmlContent: htmlContent
        )
        
        return Book(
            title: fileName,
            author: "EPUB Book",
            chapters: [chapter],
            coverImageData: nil
        )
    }
    
    func createSampleBook() throws -> Book {
        let title = "Sample Book Title"
        let author = "Sample Author"
        
        let chapterContent = """
        This is the first paragraph of chapter 1.
        This is more text for the first chapter.
        
        This is the first paragraph of chapter 2.
        This is more text for the second chapter.
        """
        
        let htmlContent = "<html><body><h1>\(title)</h1><p>\(chapterContent.replacingOccurrences(of: "\n\n", with: "</p><p>"))</p></body></html>"
        
        let chapter = Book.Chapter(title: "Chapter 1", content: chapterContent, htmlContent: htmlContent)
        
        return Book(title: title, author: author, chapters: [chapter], coverImageData: nil)
    }
} 