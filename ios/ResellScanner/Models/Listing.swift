import Foundation
import SwiftData

enum ListingStatus: String, CaseIterable, Codable {
    case draft, listed, sold

    var label: String {
        switch self {
        case .draft: "Draft"
        case .listed: "Listed"
        case .sold: "Sold"
        }
    }
}

/// Локальная история объявлений (SwiftData).
@Model
final class Listing {
    var createdAt: Date
    var platformRaw: String
    var title: String
    var brand: String?
    var draftData: Data
    var statusRaw: String = ListingStatus.draft.rawValue
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

    var status: ListingStatus {
        get { ListingStatus(rawValue: statusRaw) ?? .draft }
        set { statusRaw = newValue.rawValue }
    }
}
