import AppKit
import SwiftUI

public struct Stage3MacOSSmokeSurfaceResult: Equatable, Sendable {
    public let id: String
    public let rootView: String
    public let measuredWidth: Double
    public let measuredHeight: Double

    public init(id: String, rootView: String, measuredWidth: Double, measuredHeight: Double) {
        self.id = id
        self.rootView = rootView
        self.measuredWidth = measuredWidth
        self.measuredHeight = measuredHeight
    }
}

@MainActor
public enum Stage3MacOSSmokeRunner {
    public static func run(
        size: CGSize = CGSize(width: 1280, height: 900)
    ) throws -> [Stage3MacOSSmokeSurfaceResult] {
        _ = NSApplication.shared

        var results: [Stage3MacOSSmokeSurfaceResult] = []
        results.append(
            try realizeSurface(
                id: "root",
                rootView: Stage3MacOSRuntime.rootViewName,
                hostingView: Stage3MacOSRuntime.rootHostingView(size: size),
                size: size
            )
        )

        for page in Stage3MacOSRuntime.mirroredPages {
            guard let hostingView = Stage3MacOSRuntime.pageHostingView(for: page.id, size: size) else {
                throw NSError(
                    domain: "Stage3MacOSSmokeRunner",
                    code: 1,
                    userInfo: [
                        NSLocalizedDescriptionKey: "Could not create a mirrored macOS page surface for \(page.id)."
                    ]
                )
            }

            results.append(
                try realizeSurface(
                    id: page.id,
                    rootView: page.rootView,
                    hostingView: hostingView,
                    size: size
                )
            )
        }

        return results
    }

    public static func runDiagnosticSurfaces(
        size: CGSize = CGSize(width: 1440, height: 900)
    ) throws -> [Stage3MacOSSmokeSurfaceResult] {
        _ = NSApplication.shared

        var results: [Stage3MacOSSmokeSurfaceResult] = []

        for page in Stage3MacOSRuntime.diagnosticPages {
            guard let hostingView = Stage3MacOSRuntime.diagnosticHostingView(for: page.id, size: size) else {
                throw NSError(
                    domain: "Stage3MacOSSmokeRunner",
                    code: 3,
                    userInfo: [
                        NSLocalizedDescriptionKey: "Could not create a diagnostic macOS page surface for \(page.id)."
                    ]
                )
            }

            results.append(
                try realizeSurface(
                    id: page.id,
                    rootView: page.rootView,
                    hostingView: hostingView,
                    size: size
                )
            )
        }

        return results
    }

    private static func realizeSurface(
        id: String,
        rootView: String,
        hostingView: NSHostingView<AnyView>,
        size: CGSize
    ) throws -> Stage3MacOSSmokeSurfaceResult {
        let window = NSWindow(
            contentRect: CGRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.contentView = hostingView
        window.contentView?.layoutSubtreeIfNeeded()
        hostingView.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.05))

        let measuredSize = hostingView.fittingSize
        guard measuredSize.width > 0, measuredSize.height > 0 else {
            window.close()
            throw NSError(
                domain: "Stage3MacOSSmokeRunner",
                code: 2,
                userInfo: [
                    NSLocalizedDescriptionKey: "Surface \(id) produced an empty macOS layout."
                ]
            )
        }

        window.close()

        return Stage3MacOSSmokeSurfaceResult(
            id: id,
            rootView: rootView,
            measuredWidth: measuredSize.width,
            measuredHeight: measuredSize.height
        )
    }
}
