import SwiftUI
import AVFoundation
import UIKit
import CoreImage

/// UIViewRepresentable wrapper for displaying an AVCaptureVideoPreviewLayer.
struct PreviewLayerView: UIViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        previewLayer.frame = uiView.bounds
    }
}

/// Full screen camera preview with adjustable light intensity.
struct CameraPreviewView: View {
    /// Controller managing capture session.
    @StateObject private var cameraController = CameraSessionController()
    /// Light overlay intensity.
    @State private var lightIntensity: Double = 0.0
    /// Show settings screen
    @State private var showSettings = false
    /// Visibility of the control buttons.
    @State private var controlsVisible = true
    /// Persisted application theme
    @AppStorage("appTheme") private var appTheme: Theme = .pink

    var body: some View {
        ZStack {
            PreviewLayerView(previewLayer: cameraController.previewLayer)
                .ignoresSafeArea()
                .onTapGesture {
                    controlsVisible.toggle()
                }

            if let image = cameraController.currentImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .onTapGesture {
                        controlsVisible.toggle()
                    }
            } else {
                ThemeManager.backgroundColor(for: appTheme).ignoresSafeArea()
            }

            Color.white
                .opacity(lightIntensity)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack {
                HStack {
                    Spacer()
                    if controlsVisible {
                        Button { showSettings.toggle() } label: {
                            Image(systemName: "gearshape")
                                .font(.system(size: 20))
                                .foregroundColor(ThemeManager.foregroundColor(for: appTheme))
                                .padding(8)
                                .background(ThemeManager.backgroundColor(for: appTheme).opacity(0.6))
                                .clipShape(Circle())
                        }
                        .padding([.top, .trailing], 16)
                    }
                }
                Spacer()
                if controlsVisible {
                    HStack {
                        Spacer()
                        Button {
                            cameraController.toggleMirroring()
                        } label: {
                            Image(systemName: "arrow.left.arrow.right")
                                .font(.system(size: 24))
                                .foregroundColor(ThemeManager.foregroundColor(for: appTheme))
                                .padding()
                                .background(ThemeManager.backgroundColor(for: appTheme).opacity(0.6))
                                .clipShape(Circle())
                        }
                        Spacer()
                    }
                    .padding(.bottom, 8)
                }
                BannerAdView()
                    .frame(height: 50)
            }
            // Light intensity slider
            HStack {
                Image(systemName: "light.min")
                Slider(value: $lightIntensity, in: 0...1)
                Image(systemName: "light.max")
            }
            .padding(.leading, 20)
            .padding(.bottom, 20)
            .foregroundColor(ThemeManager.foregroundColor(for: appTheme))
            .tint(ThemeManager.foregroundColor(for: appTheme))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        }
        .onAppear {
            cameraController.startSession()
        }
        .onDisappear {
            cameraController.stopSession()
        }
        .navigationDestination(isPresented: $showSettings) {
            SettingsView()
        }
    }
}

/// Manages camera capture and publishing processed frames.
final class CameraSessionController: NSObject, ObservableObject {
    private let session = AVCaptureSession()
    private let context = CIContext()
    private let output = AVCaptureVideoDataOutput()
    lazy var previewLayer: AVCaptureVideoPreviewLayer = {
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        if let connection = layer.connection, connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
        }
        return layer
    }()

    @Published var currentImage: UIImage?

    override init() {
        super.init()
        configureSession()
    }

    /// Configure the capture session to use the front camera and video output.
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

        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "camera.queue"))
        output.alwaysDiscardsLateVideoFrames = true
        if session.canAddOutput(output) {
            session.addOutput(output)
        }
        if let connection = output.connection(with: .video), connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
        }

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

    /// Toggles horizontal mirroring on the preview layer connection.
    func toggleMirroring() {
        if let connection = previewLayer.connection,
           connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored.toggle()
        }
    }
}

extension CameraSessionController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let image = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cgImage = context.createCGImage(image, from: image.extent) else { return }
        let uiImage = UIImage(cgImage: cgImage)

        DispatchQueue.main.async {
            self.currentImage = uiImage
        }
    }
}

#Preview {
    CameraPreviewView()
}

