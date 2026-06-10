import Foundation

/// Лёгкая событийная аналитика воронки — fire-and-forget POST на воркер (/v1/event),
/// без сторонних SDK. Ошибки сети молча игнорируются: телеметрия не должна влиять на UX.
enum Analytics {
    static func track(_ event: String, platform: Platform? = nil, trigger: String? = nil) {
        var payload: [String: String] = ["event": event]
        if let platform { payload["platform"] = platform.rawValue }
        if let trigger { payload["trigger"] = trigger }
        guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return }

        var request = URLRequest(url: AppConfig.workerBaseURL.appendingPathComponent("v1/event"))
        request.httpMethod = "POST"
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(AppConfig.appToken, forHTTPHeaderField: "X-App-Token")
        request.setValue(DeviceID.current, forHTTPHeaderField: "X-Device-ID")
        request.httpBody = body

        Task.detached(priority: .background) {
            _ = try? await URLSession.shared.data(for: request)
        }
    }
}
