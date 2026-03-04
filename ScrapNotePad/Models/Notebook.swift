import Foundation

struct ScrapNotebook: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var pages: [ScrapPage]

    init(id: UUID = UUID(), title: String, createdAt: Date = .now, updatedAt: Date = .now, pages: [ScrapPage] = []) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.pages = pages
    }
}

struct ScrapPage: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var drawingData: Data
    var backgroundImageData: Data?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        drawingData: Data = Data(),
        backgroundImageData: Data? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.drawingData = drawingData
        self.backgroundImageData = backgroundImageData
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
