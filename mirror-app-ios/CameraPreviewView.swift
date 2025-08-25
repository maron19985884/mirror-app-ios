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

    /// 広告（バナー）の高さ
    private let bannerHeight: CGFloat = 50
    /// スライダー等の余白
    private let uiBottomMargin: CGFloat =  -30

    var body: some View {
        ZStack {
            // カメラプレビュー
            PreviewLayerView(previewLayer: cameraController.previewLayer)
                .ignoresSafeArea()
                .onTapGesture {
                    controlsVisible.toggle()
                }

            // currentImage がある場合の重ね合わせ（※処理は変更せず）
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

            // 白オーバーレイ（ライト調整）
            Color.white
                .opacity(lightIntensity)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            // 右上：設定ボタン
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
                // 下中央：ミラーボタン（広告の分だけ持ち上げ）
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
                    .padding(.bottom, bannerHeight + 4) // ← 広告分 + 余白
                }
            }

            // 左下：ライト調整スライダー（広告の分だけ持ち上げ）
            HStack {
                Image(systemName: "light.min")
                Slider(value: $lightIntensity, in: 0...1)
                Image(systemName: "light.max")
            }
            .padding(.leading, 20)
            .padding(.bottom, bannerHeight + uiBottomMargin) // ← 広告高さ + 余白
            .foregroundColor(ThemeManager.foregroundColor(for: appTheme))
            .tint(ThemeManager.foregroundColor(for: appTheme))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        }
        // 下部に広告を安全に固定（他UIは自動でその分持ち上がらないため、上で手動オフセット）
        .safeAreaInset(edge: .bottom) {
            BannerAdView()
                .frame(height: bannerHeight)
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
    /// Horizontal offset applied when mirroring to keep the face centered.
    private let centerOffset: CGFloat = 20
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

    func toggleMirroring() {
        // Determine the new mirroring state by toggling the current one
        let newState = !(previewLayer.connection?.isVideoMirrored ?? false)

        if let connection = previewLayer.connection,
           connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = newState

            // Shift horizontally to keep the face centered when mirrored
            let shift: CGFloat = newState ? centerOffset : 0
            previewLayer.setAffineTransform(CGAffineTransform(translationX: shift, y: 0))
        }

        if let outputConnection = output.connection(with: .video),
           outputConnection.isVideoMirroringSupported {
            outputConnection.automaticallyAdjustsVideoMirroring = false
            outputConnection.isVideoMirrored = newState
        }
    }



}

extension CameraSessionController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        var image = CIImage(cvPixelBuffer: pixelBuffer)

        if let previewConnection = previewLayer.connection, previewConnection.isVideoMirrored {
            let transform = CGAffineTransform(scaleX: -1, y: 1)
                .translatedBy(x: -image.extent.width, y: 0)
            image = image.transformed(by: transform)
        }

        // ★ 中央補正（プレビューと同じオフセットを適用）
        let shift: CGFloat = (previewLayer.connection?.isVideoMirrored ?? false) ? centerOffset : 0
        image = image.transformed(by: CGAffineTransform(translationX: shift, y: 0))

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
