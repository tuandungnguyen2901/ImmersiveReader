import SwiftUI

struct HomeView: View {
    @StateObject private var bookListModel = BookListModel()
    @State private var selectedBook: Book?
    @State private var selectedBookItem: BookListItem?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showDocumentPicker = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Main scrolling content area
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(spacing: 16) {
                        if bookListModel.isLoading {
                            ProgressView("Loading books...")
                                .frame(maxWidth: .infinity, minHeight: 200)
                        } else if let errorMessage = bookListModel.errorMessage {
                            Text("Error: \(errorMessage)")
                                .foregroundColor(.red)
                                .padding()
                                .frame(maxWidth: .infinity, minHeight: 200)
                        } else if bookListModel.books.isEmpty {
                            VStack {
                                Text("No books found")
                                    .padding()
                                
                                Button(action: {
                                    showDocumentPicker = true
                                }) {
                                    Label("Import Books", systemImage: "square.and.arrow.down")
                                        .padding()
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(8)
                                }
                            }
                            .frame(maxWidth: .infinity, minHeight: 200)
                        } else {
                            // Books list
                            ForEach(bookListModel.books) { book in
                                BookRowView(
                                    book: book, 
                                    isSelected: selectedBookItem?.id == book.id,
                                    onSelect: {
                                        selectedBookItem = book
                                        loadBook(book)
                                    },
                                    onDelete: {
                                        bookListModel.deleteBook(book)
                                    }
                                )
                            }
                            
                            // Import button only at the end of the list
                            Button(action: {
                                showDocumentPicker = true
                            }) {
                                HStack {
                                    Image(systemName: "square.and.arrow.down")
                                    Text("Import New Books")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(8)
                            }
                            .padding(.top, 8)
                            .padding(.bottom, 16)
                        }
                        
                        // Loading and error states within the scroll view
                        if isLoading {
                            ProgressView("Loading book...")
                                .padding()
                        } else if let errorMessage = errorMessage {
                            Text("Error: \(errorMessage)")
                                .foregroundColor(.red)
                                .padding()
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                }
                
                // Continue Reading button always visible at the bottom
                if let book = selectedBook, !isLoading {
                    Divider()
                    NavigationLink(
                        destination: BookReaderView(book: book),
                        label: {
                            Text("Continue Reading")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(10)
                        })
                        .padding()
                }
            }
            .navigationTitle("My Books")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showDocumentPicker = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showDocumentPicker) {
                DocumentPickerView { urls in
                    bookListModel.importBooks(from: urls)
                }
            }
            .onAppear {
                bookListModel.loadBooks()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    private func loadBook(_ bookItem: BookListItem) {
        isLoading = true
        errorMessage = nil
        selectedBookItem = bookItem
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let fileReader = FileReader()
                
                // Try to read from actual file if it exists
                if FileManager.default.fileExists(atPath: bookItem.filePath.path) {
                    let book = try fileReader.readFrom(fileURL: bookItem.filePath)
                    DispatchQueue.main.async {
                        self.selectedBook = book
                        self.isLoading = false
                    }
                } else {
                    // Fallback to sample book
                    let book = try fileReader.createSampleBook()
                    DispatchQueue.main.async {
                        self.selectedBook = book
                        self.isLoading = false
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}

// Book row component for cleaner code
struct BookRowView: View {
    let book: BookListItem
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading) {
                    Text(book.title)
                        .font(.headline)
                        .lineLimit(2)
                    Text(book.author)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "book")
                    .foregroundColor(.blue)
            }
            .padding()
            .background(isSelected ? Color.blue.opacity(0.1) : Color.gray.opacity(0.05))
            .cornerRadius(10)
        }
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

#Preview {
    HomeView()
} 