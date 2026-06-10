import Foundation

enum Platform: String, CaseIterable, Codable, Identifiable {
    case ebay, vinted, poshmark, depop, mercari, generic

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ebay: "eBay"
        case .vinted: "Vinted"
        case .poshmark: "Poshmark"
        case .depop: "Depop"
        case .mercari: "Mercari"
        case .generic: "Generic"
        }
    }

    var titleLimit: Int {
        switch self {
        case .ebay, .mercari, .generic: 80
        case .vinted: 70
        case .depop: 65
        case .poshmark: 50
        }
    }

    var usesHashtags: Bool {
        self == .vinted || self == .depop
    }
}
