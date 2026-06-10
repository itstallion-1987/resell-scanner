import AVFoundation
import SwiftUI
import UIKit

@MainActor
final class CameraService: NSObject, ObservableObject {
    let session = AVCaptureSession()
    @Published var isAuthorized = false

    private let output = AVCapturePhotoOutput()
    private var configured = false
    private var captureContinuation: CheckedContinuation<UIImage?, Never>?

    func requestAccessAndStart() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isAuthorized = true
        case .notDetermined:
            isAuthorized = await AVCaptureDevice.requestAccess(for: .video)
        default:
            isAuthorized = false
        }
        guard isAuthorized else { return }
        configureIfNeeded()
        let session = session
        if !session.isRunning {
            Task.detached { session.startRunning() }
        }
    }

    func stop() {
        let session = session
        Task.detached {
            if session.isRunning { session.stopRunning() }
        }
    }

    func capture() async -> UIImage? {
        guard session.isRunning, captureContinuation == nil else { return nil }
        return await withCheckedContinuation { continuation in
            captureContinuation = continuation
            output.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
        }
    }

    private func configureIfNeeded() {
        guard !configured else { return }
        session.beginConfiguration()
        session.sessionPreset = .photo
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
           let input = try? AVCaptureDeviceInput(device: device),
           session.canAddInput(input) {
            session.addInput(input)
        }
        if session.canAddOutput(output) {
            session.addOutput(output)
        }
        session.commitConfiguration()
        configured = true
    }
}

extension CameraService: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        let image = photo.fileDataRepresentation().flatMap(UIImage.init(data:))
        Task { @MainActor in
            captureContinuation?.resume(returning: image)
            captureContinuation = nil
        }
    }
}

/// Превью камеры для SwiftUI.
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}
}
