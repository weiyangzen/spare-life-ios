import SwiftUI

@main
struct SpareLifePreviewHostApp: App {
    init() {
        UserDefaults.standard.register(defaults: [
            "masters.chat.baseURL": "https://api.moonshot.cn/v1",
            "masters.chat.model": "kimi-k2-turbo-preview"
        ])
    }

    var body: some SwiftUI.Scene {
        WindowGroup {
            MainTabView()
                .preferredColorScheme(.light)
        }
    }
}
