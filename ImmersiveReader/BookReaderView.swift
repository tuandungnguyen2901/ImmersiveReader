import SwiftUI
import WebKit

struct BookReaderView: View {
    let book: Book
    @State private var selectedChapterIndex = 0
    
    var body: some View {
        VStack {
            HStack {
                Text(book.title)
                    .font(.headline)
                Spacer()
                Text(book.author)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()
            
            if book.chapters.isEmpty {
                Text("No content available")
                    .padding()
                Spacer()
            } else {
                // Chapter picker
                Picker("Chapter", selection: $selectedChapterIndex) {
                    ForEach(0..<book.chapters.count, id: \.self) { index in
                        Text(book.chapters[index].title).tag(index)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .padding(.horizontal)
                
                // Content display
                HTMLView(htmlContent: book.chapters[selectedChapterIndex].htmlContent)
                    .padding(.horizontal)
            }
        }
        .navigationTitle(book.title)
    }
}

// WebView to render HTML content
struct HTMLView: UIViewRepresentable {
    let htmlContent: String
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.backgroundColor = .clear
        webView.isOpaque = false
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(htmlContent, baseURL: nil)
    }
} 