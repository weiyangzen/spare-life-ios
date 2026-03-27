import SwiftUI

struct Stage1MastersPreviewRootView: View {
    @StateObject private var store = MasterExperienceStore()
    @State private var hasStarted = false

    var body: some View {
        MasterHomeView(store: store)
            .task {
                guard !hasStarted else { return }
                hasStarted = true

                if await MasterStage1Automation.maybeRun(using: store) {
                    return
                }

                store.loadIfNeeded()
            }
    }
}
