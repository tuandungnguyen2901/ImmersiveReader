import Foundation

struct BookListItem: Identifiable {
    let id = UUID()
    let title: String
    let filePath: URL
    let fileName: String
    
    // Extra metadata that could be added later
    var author: String = "Unknown"
    var coverImage: Data? = nil
}

class BookListModel: ObservableObject {
    @Published var books: [BookListItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var showImportDialog = false
    
    func loadBooks() {
        isLoading = true
        errorMessage = nil
        books = []
        
        // First, get books from local storage
        let localBooks = BookStorage.shared.getAllBooks()
        
        // Next, check for books in bundle's TestData directory
        if let testDataURL = Bundle.main.url(forResource: "TestData", withExtension: nil) {
            do {
                let fileURLs = try FileManager.default.contentsOfDirectory(at: testDataURL, includingPropertiesForKeys: nil)
                let bundleBooks = fileURLs.filter { 
                    let ext = $0.pathExtension.lowercased() 
                    return ext == "epub" || ext == "txt" || ext == "pdf"
                }.map { url in
                    let fileName = url.lastPathComponent
                    let title = url.deletingPathExtension().lastPathComponent
                    return BookListItem(title: title, filePath: url, fileName: fileName)
                }
                
                // Combine local and bundle books
                books = localBooks + bundleBooks
                
                if books.isEmpty {
                    // If no books found, add samples
                    createSampleBooks()
                }
                
            } catch {
                // If directory reading fails, still use the local books
                books = localBooks
                
                if books.isEmpty {
                    createSampleBooks()
                } else {
                    errorMessage = "Error reading bundle books: \(error.localizedDescription)"
                }
            }
        } else {
            // TestData directory not found, use local books
            books = localBooks
            
            if books.isEmpty {
                createSampleBooks()
            }
        }
        
        isLoading = false
    }
    
    func importBooks(from urls: [URL]) {
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            var importedCount = 0
            var errorCount = 0
            
            for url in urls {
                do {
                    let _ = try BookStorage.shared.importBook(from: url)
                    importedCount += 1
                } catch {
                    print("Error importing \(url.lastPathComponent): \(error)")
                    errorCount += 1
                }
            }
            
            DispatchQueue.main.async {
                self.isLoading = false
                
                if errorCount > 0 {
                    self.errorMessage = "Imported \(importedCount) books. Failed to import \(errorCount) books."
                } else if importedCount > 0 {
                    // Reload the book list
                    self.loadBooks()
                }
            }
        }
    }
    
    func deleteBook(_ book: BookListItem) {
        do {
            try BookStorage.shared.deleteBook(at: book.filePath)
            // Remove from list
            if let index = books.firstIndex(where: { $0.id == book.id }) {
                books.remove(at: index)
            }
        } catch {
            errorMessage = "Failed to delete book: \(error.localizedDescription)"
        }
    }
    
    private func createSampleBooks() {
        // Empty implementation - no more sample books
        books = []
    }
} 