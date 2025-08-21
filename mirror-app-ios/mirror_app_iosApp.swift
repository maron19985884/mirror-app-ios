//
//  mirror_app_iosApp.swift
//  mirror-app-ios
//
//  Created by 小林　景大 on 2025/08/21.
//

import SwiftUI
import GoogleMobileAds

@main
struct mirror_app_iosApp: App {
    init() {
        GADMobileAds.sharedInstance().start(completionHandler: nil)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
