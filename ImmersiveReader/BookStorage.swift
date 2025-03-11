import Foundation
import UIKit
import SwiftUI
import UniformTypeIdentifiers

class BookStorage: ObservableObject {
    static let shared = BookStorage()
    
    private let fileManager = FileManager.default
    
    // Directory for storing imported books
    private var booksDirectory: URL {
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let booksDirectory = documentsDirectory.appendingPathComponent("Books", isDirectory: true)
        
        // Create directory if it doesn't exist
        if !fileManager.fileExists(atPath: booksDirectory.path) {
            try? fileManager.createDirectory(at: booksDirectory, withIntermediateDirectories: true)
        }
        
        return booksDirectory
    }
    
    // Import a book from a URL (can be a local file URL or remote URL)
    func importBook(from sourceURL: URL) throws -> URL {
        // Generate a unique filename
        let fileName = sourceURL.lastPathComponent
        let destinationURL = booksDirectory.appendingPathComponent(fileName)
        
        // If file with same name already exists, remove it
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        
        // Copy file to app's storage
        try fileManager.copyItem(at: sourceURL, to: destinationURL)
        
        return destinationURL
    }
    
    // Get all stored books
    func getAllBooks() -> [BookListItem] {
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: booksDirectory, includingPropertiesForKeys: nil)
            let bookFiles = fileURLs.filter { 
                let ext = $0.pathExtension.lowercased()
                return ext == "epub" || ext == "txt" || ext == "pdf"
            }
            
            return bookFiles.map { url in
                let fileName = url.lastPathComponent
                let title = url.deletingPathExtension().lastPathComponent
                    .replacingOccurrences(of: "_", with: " ")
                    .capitalized
                
                return BookListItem(title: title, filePath: url, fileName: fileName)
            }
        } catch {
            print("Error getting stored books: \(error)")
            return []
        }
    }
    
    // Delete a book by its URL
    func deleteBook(at url: URL) throws {
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }
}

// Document picker controller to import books
struct DocumentPickerView: UIViewControllerRepresentable {
    var onDocumentsPicked: ([URL]) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let supportedTypes: [UTType] = [.text, .pdf, .epub]
        let controller = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes)
        controller.allowsMultipleSelection = true
        controller.delegate = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {
        // Nothing to update
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPickerView
        
        init(_ parent: DocumentPickerView) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            parent.onDocumentsPicked(urls)
        }
    }
} 