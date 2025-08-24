import SwiftUI
import GoogleMobileAds

struct BannerAdView: UIViewRepresentable {
    func makeUIView(context: Context) -> BannerView {
        // 新しい BannerView を作成
        let banner = BannerView(adSize: AdSizeBanner)
        banner.adUnitID = "ca-app-pub-3940256099942544/2934735716" // テスト用ID
        banner.rootViewController = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first?.rootViewController
        banner.load(Request())
        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) {
        // 今回は更新不要
    }
}

#Preview {
    BannerAdView()
        .frame(height: 50)
}
