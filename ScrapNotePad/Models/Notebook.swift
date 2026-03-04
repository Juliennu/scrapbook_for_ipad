import Foundation
import CoreGraphics

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

struct ScrapImageItem: Identifiable, Codable, Hashable {
    var id: UUID
    var imageData: Data
    var center: CGPoint
    var baseSize: CGSize
    var scale: CGFloat
    var zIndex: Double

    init(
        id: UUID = UUID(),
        imageData: Data,
        center: CGPoint,
        baseSize: CGSize,
        scale: CGFloat = 1.0,
        zIndex: Double = 0
    ) {
        self.id = id
        self.imageData = imageData
        self.center = center
        self.baseSize = baseSize
        self.scale = scale
        self.zIndex = zIndex
    }
}

struct ScrapPage: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var drawingData: Data
    var backgroundImageData: Data?
    var imageItems: [ScrapImageItem]
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        drawingData: Data = Data(),
        backgroundImageData: Data? = nil,
        imageItems: [ScrapImageItem] = [],
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.drawingData = drawingData
        self.backgroundImageData = backgroundImageData
        self.imageItems = imageItems
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case drawingData
        case backgroundImageData
        case imageItems
        case createdAt
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        drawingData = try container.decode(Data.self, forKey: .drawingData)
        backgroundImageData = try container.decodeIfPresent(Data.self, forKey: .backgroundImageData)
        imageItems = try container.decodeIfPresent([ScrapImageItem].self, forKey: .imageItems) ?? []
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
}
