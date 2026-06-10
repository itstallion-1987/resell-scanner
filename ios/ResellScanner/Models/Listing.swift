import Foundation
import SwiftData

/// Локальная история объявлений (SwiftData).
@Model
final class Listing {
    var createdAt: Date
    var platformRaw: String
    var title: String
    var brand: String?
    var draftData: Data
    @Attribute(.externalStorage) var thumbnail: Data?

    init(draft: ListingDraft, platform: Platform, thumbnail: Data?) {
        self.createdAt = .now
        self.platformRaw = platform.rawValue
        self.title = draft.title
        self.brand = draft.brand
        self.draftData = (try? JSONEncoder().encode(draft)) ?? Data()
        self.thumbnail = thumbnail
    }

    var draft: ListingDraft? {
        try? JSONDecoder().decode(ListingDraft.self, from: draftData)
    }

    var platform: Platform {
        Platform(rawValue: platformRaw) ?? .generic
    }
}
