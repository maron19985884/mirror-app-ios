import SwiftUI
import GoogleMobileAds

@main
struct mirror_app_iosApp: App {
    init() {
        // v12 以降の初期化方法
        MobileAds.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
