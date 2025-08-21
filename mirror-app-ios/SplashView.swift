import SwiftUI

/// Initial splash screen shown on app launch
struct SplashView: View {
    /// Persistently selected theme (defaults to light)
    @AppStorage("selectedTheme") private var selectedTheme: Theme = .light
    /// Controls navigation to the camera preview screen
    @State private var navigateToCamera: Bool = false

    var body: some View {
        ZStack(alignment: .bottom) {
            ThemeManager.backgroundColor(for: selectedTheme)
                .ignoresSafeArea()

            VStack {
                Spacer()
                Text("MirrorApp")
                    .font(.largeTitle)
                    .foregroundColor(ThemeManager.foregroundColor(for: selectedTheme))
                Spacer()
                Text("タップして開始 ▶︎")
                    .foregroundColor(ThemeManager.foregroundColor(for: selectedTheme))
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
