import SwiftUI

@main
struct SpareLifePreviewHostApp: App {
    var body: some SwiftUI.Scene {
        WindowGroup {
            MainTabView()
                .preferredColorScheme(.light)
        }
    }
}
