import SwiftUI
import AVFoundation

/// Full screen camera preview using the front camera.
struct CameraPreviewView: View {
    /// Controller managing the capture session.
    @StateObject private var cameraController = CameraSessionController()
    /// Whether the full-screen light overlay is visible.
    @State private var lightOn = false
    /// Controls presentation of the filter settings sheet.
    @State private var showFilterSheet = false
    /// Whether the preview is mirrored horizontally.
    @State private var mirrored = false
    /// Visibility of the control buttons.
    @State private var controlsVisible = true

    var body: some View {
        ZStack {
            CameraPreviewLayerView(session: cameraController.session, mirrored: mirrored)
                .ignoresSafeArea()
                .onAppear {
                    cameraController.startSession()
                }
                .onDisappear {
                    cameraController.stopSession()
                }
                .onTapGesture {
                    controlsVisible.toggle()
                }

            if lightOn {
                Color.white
                    .opacity(0.9)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            if controlsVisible {
                VStack {
                    Spacer()
                    HStack(spacing: 40) {
                        Button {
                            lightOn.toggle()
                        } label: {
                            Image(systemName: lightOn ? "lightbulb.fill" : "lightbulb")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }

                        Button {
                            showFilterSheet.toggle()
                        } label: {
                            Image(systemName: "paintpalette")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }

                        Button {
                            mirrored.toggle()
                        } label: {
                            Image(systemName: "arrow.left.arrow.right")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .sheet(isPresented: $showFilterSheet) {
            FilterSettingsView()
        }
    }
}

/// A UIViewRepresentable that wraps `AVCaptureVideoPreviewLayer` for SwiftUI.
struct CameraPreviewLayerView: UIViewRepresentable {
    let session: AVCaptureSession
    /// Whether the preview should be mirrored horizontally.
    var mirrored: Bool

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView(session: session)
        view.setMirrored(mirrored)
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {
        uiView.setMirrored(mirrored)
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

        /// Applies horizontal mirroring to the preview.
        func setMirrored(_ mirrored: Bool) {
            transform = mirrored ? CGAffineTransform(scaleX: -1, y: 1) : .identity
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

/// Placeholder filter settings sheet.
struct FilterSettingsView: View {
    @State private var beautyLevel = 0
    @State private var colorAdjust = false

    var body: some View {
        NavigationView {
            Form {
                Picker("美肌補正", selection: $beautyLevel) {
                    Text("なし").tag(0)
                    Text("弱").tag(1)
                    Text("中").tag(2)
                    Text("強").tag(3)
                }

                Toggle("色調補正", isOn: $colorAdjust)
            }
            .navigationTitle("フィルター設定")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    CameraPreviewView()
}
