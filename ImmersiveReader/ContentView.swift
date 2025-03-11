//
//  ContentView.swift
//  ImmersiveReader
//
//  Created by admin on 11/3/25.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Item.timestamp, ascending: true)],
        animation: .default)
    private var items: FetchedResults<Item>

    @State private var book: Book?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("Loading book...")
                } else if let errorMessage = errorMessage {
                    Text("Error: \(errorMessage)")
                        .foregroundColor(.red)
                        .padding()
                } else if let book = book {
                    BookReaderView(book: book)
                } else {
                    List {
                        ForEach(items) { item in
                            NavigationLink {
                                Text("Item at \(item.timestamp!, formatter: itemFormatter)")
                            } label: {
                                Text(item.timestamp!, formatter: itemFormatter)
                            }
                        }
                        .onDelete(perform: deleteItems)
                    }
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            EditButton()
                        }
                        ToolbarItem {
                            Button(action: addItem) {
                                Label("Add Item", systemImage: "plus")
                            }
                        }
                    }
                    
                    Button("Load EPUB Book") {
                        loadEPUBBook()
                    }
                    .padding()

                    Button("Debug: List Bundle Contents") {
                        self.errorMessage = listBundleContents()
                    }
                    .padding()

                    Button("Create and Load Sample") {
                        createAndLoadSampleFile()
                    }
                    .padding()
                }
            }
        }
    }

    private func loadEPUBBook() {
        isLoading = true
        errorMessage = nil
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // Use the simpler approach that doesn't rely on bundle files
                let fileReader = FileReader()
                let loadedBook = try fileReader.createSampleBook()
                
                DispatchQueue.main.async {
                    self.book = loadedBook
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                    print("Error loading book: \(error)")
                }
            }
        }
    }

    private func createAndLoadSampleFile() {
        isLoading = true
        errorMessage = nil
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // Create sample content
                let sampleContent = """
                Sample Book Title
                Sample Author
                
                Chapter 1
                
                This is the first paragraph of chapter 1.
                This is more text for the first chapter.
                
                Chapter 2
                
                This is the first paragraph of chapter 2.
                This is more text for the second chapter.
                """
                
                // Create a temporary file
                let tempDir = FileManager.default.temporaryDirectory
                let fileURL = tempDir.appendingPathComponent("sample.txt")
                
                // Write content to the file
                try sampleContent.write(to: fileURL, atomically: true, encoding: .utf8)
                
                // Read the file back
                let fileReader = FileReader()
                let book = try fileReader.readFrom(fileURL: fileURL)
                
                DispatchQueue.main.async {
                    self.book = book
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to create sample file: \(error.localizedDescription)"
                    self.isLoading = false
                    print("Error creating sample file: \(error)")
                }
            }
        }
    }

    private func addItem() {
        withAnimation {
            let newItem = Item(context: viewContext)
            newItem.timestamp = Date()

            do {
                try viewContext.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            offsets.map { items[$0] }.forEach(viewContext.delete)

            do {
                try viewContext.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }

    func listBundleContents() -> String {
        let fileManager = FileManager.default
        var output = ""
        
        guard let bundleURL = Bundle.main.resourceURL else {
            return "Could not access bundle URL"
        }
        
        output += "Bundle path: \(bundleURL.path)\n\n"
        
        do {
            let items = try fileManager.contentsOfDirectory(atPath: bundleURL.path)
            output += "Bundle contents:\n"
            for item in items {
                output += "• \(item)\n"
                
                // If it might be a directory, try to look inside
                let itemPath = bundleURL.appendingPathComponent(item).path
                var isDir: ObjCBool = false
                if fileManager.fileExists(atPath: itemPath, isDirectory: &isDir) && isDir.boolValue {
                    do {
                        let subItems = try fileManager.contentsOfDirectory(atPath: itemPath)
                        for subItem in subItems {
                            output += "  - \(subItem)\n"
                        }
                    } catch {
                        output += "  (Could not read directory contents: \(error))\n"
                    }
                }
            }
        } catch {
            output += "Error listing bundle contents: \(error)"
        }
        
        return output
    }
}

private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .medium
    return formatter
}()

#Preview {
    ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
