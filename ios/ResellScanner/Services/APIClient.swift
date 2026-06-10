import Foundation
import UIKit

enum APIError: LocalizedError {
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
}

enum APIClient {
    // TODO: заменить на URL задеплоенного воркера и общий секрет (APP_SHARED_SECRET)
    static let baseURL = URL(string: "https://resell-scanner-proxy.YOUR-SUBDOMAIN.workers.dev")!
    static let appToken = "REPLACE_APP_SHARED_SECRET"

    static func generateListing(
        images: [UIImage],
        platform: Platform,
        currency: String,
        note: String?,
        rcUserId: String?
    ) async throws -> GenerateResponse {
        // Ужимаем фото до отправки: 3 кадра должны улетать по LTE за секунды
        let payloadImages: [[String: String]] = images.prefix(3).compactMap { image in
            guard let data = image.resizedJPEG(maxDimension: 1568, quality: 0.7) else { return nil }
            return ["data": data.base64EncodedString(), "media_type": "image/jpeg"]
        }
        guard !payloadImages.isEmpty else { throw APIError.server }

        var body: [String: Any] = [
            "images": payloadImages,
            "platform": platform.rawValue,
            "currency": currency,
        ]
        if let note, !note.isEmpty { body["note"] = note }

        var request = URLRequest(url: baseURL.appendingPathComponent("v1/listing"))
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(appToken, forHTTPHeaderField: "X-App-Token")
        request.setValue(DeviceID.current, forHTTPHeaderField: "X-Device-ID")
        if let rcUserId {
            request.setValue(rcUserId, forHTTPHeaderField: "X-RC-User-ID")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

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
            let err = try? JSONDecoder().decode([String: String].self, from: data)
            throw err?["error"] == "daily_cap_reached" ? APIError.dailyCapReached : APIError.freeLimitReached
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
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in draw(in: CGRect(origin: .zero, size: newSize)) }
        return resized.jpegData(compressionQuality: quality)
    }
}
