import Foundation

struct Book {
    let title: String
    let author: String
    let chapters: [Chapter]
    let coverImageData: Data?
    
    struct Chapter {
        let title: String
        let content: String
        let htmlContent: String
    }
} 