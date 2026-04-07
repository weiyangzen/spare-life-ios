import SwiftUI

enum MainTab: String, CaseIterable, Identifiable {
    case xianxia
    case master
    case earnSocial
    case messages
    case myProfile

    var id: String { rawValue }
}

struct MainTabView: View {
    var body: some View {
        Stage3MacOSSharedRootView()
    }
}
