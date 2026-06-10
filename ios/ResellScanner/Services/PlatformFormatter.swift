import Foundation

struct FormattedListing {
    var title: String
    var description: String
}

/// Локальное переформатирование черновика под платформу — переключение платформ
/// на экране результата НЕ делает нового vision-вызова.
enum PlatformFormatter {
    static func format(_ draft: ListingDraft, for platform: Platform) -> FormattedListing {
        FormattedListing(
            title: truncateAtWord(draft.title, limit: platform.titleLimit),
            description: buildDescription(draft, platform: platform)
        )
    }

    static func copyAllText(_ draft: ListingDraft, platform: Platform) -> String {
        let formatted = format(draft, for: platform)
        var lines = [formatted.title, "", formatted.description]
        if !platform.usesHashtags, !draft.keywords.isEmpty {
            lines += ["", "Keywords: " + draft.keywords.joined(separator: ", ")]
        }
        if draft.priceRange.low != nil {
            lines += ["", "Price estimate: \(draft.priceRangeText) (\(draft.priceRange.note))"]
        }
        return lines.joined(separator: "\n")
    }

    private static func buildDescription(_ draft: ListingDraft, platform: Platform) -> String {
        var parts: [String] = []
        switch platform {
        case .poshmark:
            parts.append(draft.description)
            var bullets: [String] = []
            if let brand = draft.brand { bullets.append("• Brand: \(brand)") }
            if let model = draft.model { bullets.append("• Style: \(model)") }
            if let size = draft.size { bullets.append("• Size: \(size)") }
            if let materials = draft.materials { bullets.append("• Materials: \(materials)") }
            bullets.append("• Condition: \(draft.conditionLabel) — \(draft.conditionDetails)")
            parts.append(bullets.joined(separator: "\n"))

        case .vinted, .depop:
            parts.append(firstSentences(of: draft.description, count: 2))
            parts.append("Condition: \(draft.conditionLabel). \(draft.conditionDetails)")
            let tags = draft.keywords.prefix(5)
                .map { "#" + $0.replacingOccurrences(of: " ", with: "").lowercased() }
            if !tags.isEmpty { parts.append(tags.joined(separator: " ")) }

        case .ebay, .mercari, .generic:
            parts.append(draft.description)
            var specs: [String] = []
            if let brand = draft.brand { specs.append("Brand: \(brand)") }
            if let model = draft.model { specs.append("Model: \(model)") }
            if let size = draft.size { specs.append("Size: \(size)") }
            if let materials = draft.materials { specs.append("Materials: \(materials)") }
            if !specs.isEmpty { parts.append(specs.joined(separator: "\n")) }
            parts.append("Condition: \(draft.conditionLabel). \(draft.conditionDetails)")
        }
        return parts.filter { !$0.isEmpty }.joined(separator: "\n\n")
    }

    private static func truncateAtWord(_ text: String, limit: Int) -> String {
        guard text.count > limit else { return text }
        let cut = String(text.prefix(limit))
        if let lastSpace = cut.lastIndex(of: " ") {
            return String(cut[..<lastSpace])
        }
        return cut
    }

    private static func firstSentences(of text: String, count: Int) -> String {
        var sentences: [String] = []
        text.enumerateSubstrings(in: text.startIndex..., options: .bySentences) { substring, _, _, stop in
            if let s = substring { sentences.append(s) }
            if sentences.count >= count { stop = true }
        }
        return sentences.joined().trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
