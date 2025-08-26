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
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        previewLayer.frame = uiView.bounds
    }
}

/// Full screen camera preview with adjustable light intensity.
struct CameraPreviewView: View {
    @StateObject private var cameraController = CameraSessionController()
    @State private var lightIntensity: Double = 0.0
    @State private var showSettings = false
    @State private var controlsVisible = true
    @AppStorage("appTheme") private var appTheme: Theme = .pink

    private let bannerHeight: CGFloat = 50
    private let uiBottomMargin: CGFloat = -30

    var body: some View {
        ZStack {
            // カメラプレビュー
            PreviewLayerView(previewLayer: cameraController.previewLayer)
                .ignoresSafeArea()
                .onTapGesture { controlsVisible.toggle() }

            // currentImage（保存用プレビュー）
            if let image = cameraController.currentImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .onTapGesture { controlsVisible.toggle() }
            } else {
                ThemeManager.backgroundColor(for: appTheme).ignoresSafeArea()
            }

            // 白オーバーレイ（ライト調整）
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
                    .padding(.bottom, bannerHeight + 4)
                }
            }

            // 左下：ライト調整スライダー
            HStack {
                Image(systemName: "light.min")
                Slider(value: $lightIntensity, in: 0...1)
                Image(systemName: "light.max")
            }
            .padding(.leading, 20)
            .padding(.bottom, bannerHeight + uiBottomMargin)
            .foregroundColor(ThemeManager.foregroundColor(for: appTheme))
            .tint(ThemeManager.foregroundColor(for: appTheme))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        }
        .safeAreaInset(edge: .bottom) {
            BannerAdView()
                .frame(height: bannerHeight)
        }
        .onAppear { cameraController.startSession() }
        .onDisappear { cameraController.stopSession() }
        .navigationDestination(isPresented: $showSettings) {
            SettingsView()
        }
    }
}

/// カメラ制御クラス
final class CameraSessionController: NSObject, ObservableObject {
    private let session = AVCaptureSession()
    private let context = CIContext()
    private let output = AVCaptureVideoDataOutput()

    lazy var previewLayer: AVCaptureVideoPreviewLayer = {
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        if let connection = layer.connection, connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
            // デフォルトで鏡像にしておく（iPhone標準カメラと同じ）
            if connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = true
            }
        }
        return layer
    }()

    @Published var currentImage: UIImage?

    override init() {
        super.init()
        configureSession()
    }

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

    func startSession() {
        guard !session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            self.session.startRunning()
        }
    }

    func stopSession() {
        guard session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            self.session.stopRunning()
        }
    }

    /// プレビュー反転切替（保存画像は常に実像）
    func toggleMirroring() {
        guard let connection = previewLayer.connection else { return }
        if connection.isVideoMirroringSupported {
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

        // ✅ 保存用画像は常に実像（反転処理なし）
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
