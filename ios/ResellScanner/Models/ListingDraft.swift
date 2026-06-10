import Foundation

/// Зеркало JSON-схемы ответа воркера (см. proxy/src/schema.ts).
struct ListingDraft: Codable, Equatable {
    var recognized: Bool
    var confidence: String
    var title: String
    var brand: String?
    var model: String?
    var category: String
    var size: String?
    var materials: String?
    var condition: String
    var conditionDetails: String
    var description: String
    var keywords: [String]
    var priceRange: PriceRange
    var soldCompsQuery: String
    var retryHint: String?

    struct PriceRange: Codable, Equatable {
        var low: Double?
        var high: Double?
        var currency: String
        var note: String
    }

    enum CodingKeys: String, CodingKey {
        case recognized, confidence, title, brand, model, category, size, materials, condition
        case conditionDetails = "condition_details"
        case description, keywords
        case priceRange = "price_range"
        case soldCompsQuery = "sold_comps_query"
        case retryHint = "retry_hint"
    }

    var conditionLabel: String {
        switch condition {
        case "new_with_tags": "New with tags"
        case "like_new": "Like new"
        case "good": "Good"
        case "fair": "Fair"
        case "poor": "Poor"
        default: condition
        }
    }

    var priceRangeText: String {
        guard let low = priceRange.low, let high = priceRange.high else { return "—" }
        return "\(Int(low))–\(Int(high)) \(priceRange.currency)"
    }
}

struct GenerateResponse: Codable {
    var draft: ListingDraft
    var meta: Meta

    struct Meta: Codable {
        var isPro: Bool
        var remainingFree: Int

        enum CodingKeys: String, CodingKey {
            case isPro = "is_pro"
            case remainingFree = "remaining_free"
        }
    }
}
