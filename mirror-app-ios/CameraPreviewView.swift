import SwiftUI
import AVFoundation

/// Full screen camera preview using the front camera.
struct CameraPreviewView: View {
    /// Controller managing the capture session.
    @StateObject private var cameraController = CameraSessionController()

    var body: some View {
        CameraPreviewLayerView(session: cameraController.session)
            .ignoresSafeArea()
            .onAppear {
                cameraController.startSession()
            }
            .onDisappear {
                cameraController.stopSession()
            }
    }
}

/// A UIViewRepresentable that wraps `AVCaptureVideoPreviewLayer` for SwiftUI.
struct CameraPreviewLayerView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewUIView {
        PreviewUIView(session: session)
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {
        // Nothing to update since session is managed externally.
    }

    /// UIView subclass whose backing layer is an `AVCaptureVideoPreviewLayer`.
    final class PreviewUIView: UIView {
        private let session: AVCaptureSession

        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }

        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }

        init(session: AVCaptureSession) {
            self.session = session
            super.init(frame: .zero)
            videoPreviewLayer.session = session
            videoPreviewLayer.videoGravity = .resizeAspectFill
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            videoPreviewLayer.frame = bounds
        }
    }
}

/// Manages the configuration and lifecycle of the `AVCaptureSession`.
final class CameraSessionController: NSObject, ObservableObject {
    let session = AVCaptureSession()

    override init() {
        super.init()
        configureSession()
    }

    /// Configure the capture session to use the front camera.
    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .high

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                  for: .video,
                                                  position: .front),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            session.commitConfiguration()
            return
        }

        session.addInput(input)
        session.commitConfiguration()
    }

    /// Starts the capture session on a background thread.
    func startSession() {
        guard !session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            self.session.startRunning()
        }
    }

    /// Stops the capture session on a background thread.
    func stopSession() {
        guard session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            self.session.stopRunning()
        }
    }
}

#Preview {
    CameraPreviewView()
}
