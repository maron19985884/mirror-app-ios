import SwiftUI
import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins

/// Full screen camera preview with optional beauty and tone correction filters.
struct CameraPreviewView: View {
    /// Controller managing capture and filtering.
    @StateObject private var cameraController = CameraSessionController()
    /// Whether the full-screen light overlay is visible.
    @State private var lightOn = false
    /// Controls presentation of the filter settings sheet.
    @State private var showFilterSheet = false
    /// Show settings screen
    @State private var showSettings = false
    /// Visibility of the control buttons.
    @State private var controlsVisible = true
    /// Skin smoothing intensity: 0=none, 1=low, 2=medium, 3=high.
    @State private var skinSmoothing = 0
    /// Whether tone correction is applied.
    @State private var toneCorrection = false
    /// Persisted application theme
    @AppStorage("appTheme") private var appTheme: Theme = .light

    var body: some View {
        ZStack {
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

            if lightOn {
                Color.white
                    .opacity(0.9)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

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
                    HStack(spacing: 40) {
                        Button {
                            lightOn.toggle()
                        } label: {
                            Image(systemName: lightOn ? "lightbulb.fill" : "lightbulb")
                                .font(.system(size: 24))
                                .foregroundColor(ThemeManager.foregroundColor(for: appTheme))
                                .padding()
                                .background(ThemeManager.backgroundColor(for: appTheme).opacity(0.6))
                                .clipShape(Circle())
                        }

                        Button {
                            showFilterSheet.toggle()
                        } label: {
                            Image(systemName: "paintpalette")
                                .font(.system(size: 24))
                                .foregroundColor(ThemeManager.foregroundColor(for: appTheme))
                                .padding()
                                .background(ThemeManager.backgroundColor(for: appTheme).opacity(0.6))
                                .clipShape(Circle())
                        }

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
                    }
                    .padding(.bottom, 8)
                }
                BannerAdView()
                    .frame(height: 50)
            }
        }
        .onAppear {
            cameraController.startSession()
        }
        .onDisappear {
            cameraController.stopSession()
        }
        .onChange(of: skinSmoothing) { cameraController.skinSmoothing = $0 }
        .onChange(of: toneCorrection) { cameraController.toneCorrection = $0 }
        .sheet(isPresented: $showFilterSheet) {
            FilterSettingsView(skinSmoothing: $skinSmoothing, toneCorrection: $toneCorrection)
        }
        .navigationDestination(isPresented: $showSettings) {
            SettingsView()
        }
    }
}

/// Manages camera capture, filtering, and publishing processed frames.
final class CameraSessionController: NSObject, ObservableObject {
    private let session = AVCaptureSession()
    private let context = CIContext()
    private let output = AVCaptureVideoDataOutput()

    @Published var currentImage: UIImage?

    /// Skin smoothing intensity: 0=none, 1=low, 2=medium, 3=high.
    var skinSmoothing: Int = 0
    /// Whether tone correction is applied.
    var toneCorrection: Bool = false

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

    /// Toggles horizontal mirroring on the video connection.
    func toggleMirroring() {
        if let connection = output.connection(with: .video),
           connection.isVideoOrientationSupported {
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
        var image = CIImage(cvPixelBuffer: pixelBuffer)

        // Apply skin smoothing using a gaussian blur with varying radius.
        if skinSmoothing > 0 {
            let radius: Double
            switch skinSmoothing {
            case 1: radius = 2
            case 2: radius = 5
            case 3: radius = 8
            default: radius = 0
            }
            let blur = CIFilter.gaussianBlur()
            blur.inputImage = image
            blur.radius = Float(radius)
            if let blurred = blur.outputImage {
                image = blurred.cropped(to: image.extent)
            }
        }

        // Apply optional tone correction.
        if toneCorrection {
            let color = CIFilter.colorControls()
            color.inputImage = image
            color.saturation = 1.2
            color.contrast = 1.1
            color.brightness = 0.05
            if let corrected = color.outputImage {
                image = corrected
            }
        }

        guard let cgImage = context.createCGImage(image, from: image.extent) else { return }
        let uiImage = UIImage(cgImage: cgImage)

        DispatchQueue.main.async {
            self.currentImage = uiImage
        }
    }
}

/// Filter settings sheet allowing adjustment of processing parameters.
struct FilterSettingsView: View {
    @Binding var skinSmoothing: Int
    @Binding var toneCorrection: Bool

    var body: some View {
        NavigationView {
            Form {
                Picker("美肌補正", selection: $skinSmoothing) {
                    Text("なし").tag(0)
                    Text("弱").tag(1)
                    Text("中").tag(2)
                    Text("強").tag(3)
                }

                Toggle("色調補正", isOn: $toneCorrection)
            }
            .navigationTitle("フィルター設定")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    CameraPreviewView()
}

