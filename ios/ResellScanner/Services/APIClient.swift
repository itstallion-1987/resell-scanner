import Foundation
import UIKit

enum APIError: LocalizedError, Equatable {
    case freeLimitReached
    case dailyCapReached
    case modelBusy
    case server
    case network

    var errorDescription: String? {
        switch self {
        case .freeLimitReached: "You've used all free listings. Upgrade to Pro for unlimited listings."
        case .dailyCapReached: "Daily limit reached. Please try again tomorrow."
        case .modelBusy: "The service is busy. Please try again in a moment."
        case .server: "Generation failed. Please try again."
        case .network: "No connection. Check your internet and try again."
        }
    }

    /// Транзиентные ошибки, на которых имеет смысл один автоматический повтор
    var isRetryable: Bool { self == .modelBusy || self == .network }
}

enum APIClient {
    static func generateListing(
        images: [UIImage],
        platform: Platform,
        currency: String,
        note: String?,
        rcUserId: String?
    ) async throws -> GenerateResponse {
        // Сжимаем один раз, повтор переиспользует готовый payload — бесплатен по UX.
        // 1280px: на тестовом наборе бирки уверенно читались даже с 896px, а входных
        // vision-токенов на треть меньше, чем при 1568 — быстрее и дешевле.
        let payloadImages: [[String: String]] = images.prefix(3).compactMap { image in
            guard let data = image.resizedJPEG(maxDimension: 1280, quality: 0.7) else { return nil }
            return ["data": data.base64EncodedString(), "media_type": "image/jpeg"]
        }
        guard !payloadImages.isEmpty else { throw APIError.server }

        var body: [String: Any] = [
            "images": payloadImages,
            "platform": platform.rawValue,
            "currency": currency,
        ]
        if let note, !note.isEmpty { body["note"] = note }
        if let language = AppConfig.deviceLanguage { body["language"] = language }

        let payload = try JSONSerialization.data(withJSONObject: body)

        do {
            return try await perform(payload: payload, rcUserId: rcUserId)
        } catch let error as APIError where error.isRetryable {
            // Один повтор с бэкоффом — спасает конвейер на нестабильном LTE
            try? await Task.sleep(for: .seconds(1.5))
            return try await perform(payload: payload, rcUserId: rcUserId)
        }
    }

    private static func perform(payload: Data, rcUserId: String?) async throws -> GenerateResponse {
        var request = URLRequest(url: AppConfig.workerBaseURL.appendingPathComponent("v1/listing"))
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(AppConfig.appToken, forHTTPHeaderField: "X-App-Token")
        request.setValue(DeviceID.current, forHTTPHeaderField: "X-Device-ID")
        if let rcUserId {
            request.setValue(rcUserId, forHTTPHeaderField: "X-RC-User-ID")
        }
        request.httpBody = payload

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw APIError.network
        }
        guard let http = response as? HTTPURLResponse else { throw APIError.network }

        switch http.statusCode {
        case 200:
            return try JSONDecoder().decode(GenerateResponse.self, from: data)
        case 402:
            struct ErrorBody: Decodable { let error: String }
            let err = try? JSONDecoder().decode(ErrorBody.self, from: data)
            throw err?.error == "daily_cap_reached" ? APIError.dailyCapReached : APIError.freeLimitReached
        case 503:
            throw APIError.modelBusy
        default:
            throw APIError.server
        }
    }
}

extension UIImage {
    func resizedJPEG(maxDimension: CGFloat, quality: CGFloat) -> Data? {
        let longest = max(size.width, size.height)
        guard longest > maxDimension else { return jpegData(compressionQuality: quality) }
        let scale = maxDimension / longest
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        // scale = 1: иначе рендер берёт масштаб дисплея (2-3x) и 1568pt дают ~4700px —
        // payload раздувается и упирается в лимит Anthropic 5 МБ/фото
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        let resized = renderer.image { _ in draw(in: CGRect(origin: .zero, size: newSize)) }
        return resized.jpegData(compressionQuality: quality)
    }
}
