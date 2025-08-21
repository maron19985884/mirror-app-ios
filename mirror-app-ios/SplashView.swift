import SwiftUI

/// Initial splash screen shown on app launch
struct SplashView: View {
    /// Persisted application theme (defaults to light)
    @AppStorage("appTheme") private var appTheme: Theme = .light
    /// Controls navigation to the camera preview screen
    @State private var navigateToCamera: Bool = false

    var body: some View {
        ZStack(alignment: .bottom) {
            ThemeManager.backgroundColor(for: appTheme)
                .ignoresSafeArea()

            VStack {
                Spacer()
                Text("MirrorApp")
                    .font(.largeTitle)
                    .foregroundColor(ThemeManager.foregroundColor(for: appTheme))
                Spacer()
                Text("タップして開始 ▶︎")
                    .foregroundColor(ThemeManager.foregroundColor(for: appTheme))
                    .padding(.bottom, 40)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            navigateToCamera = true
        }
        .navigationDestination(isPresented: $navigateToCamera) {
            CameraPreviewView()
        }
    }
}

#Preview {
    NavigationStack {
        SplashView()
    }
}
