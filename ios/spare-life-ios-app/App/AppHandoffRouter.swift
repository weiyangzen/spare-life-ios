import Foundation

@MainActor
final class AppHandoffRouter: ObservableObject {
    @Published private(set) var lastHandoff: CrossTabHandoff?
    @Published private(set) var handoffSerial: UInt64 = 0

    func open(_ handoff: CrossTabHandoff) {
        lastHandoff = handoff
        handoffSerial &+= 1
    }

    func openLegacyRoute(
        _ rawRoute: String,
        sourceSurface: AppSurfaceID,
        homeTab: String = "recent"
    ) {
        guard let handoff = LegacyAppRouteNormalizer.normalize(
            rawRoute,
            sourceSurface: sourceSurface,
            homeTab: homeTab
        ) else {
            return
        }

        open(handoff)
    }
}
