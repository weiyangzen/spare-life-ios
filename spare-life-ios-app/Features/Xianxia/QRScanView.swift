// QRScanView.swift
// Spare Life – 咸虾 QR code scanner sheet
// Blueprint §3.1 功能点1: 扫码进入场景话题页
// Supports: QR code, short link, activity code, invite code
// UIUX lane – slot 2

import SwiftUI
import AVFoundation

// MARK: - QRScanView

struct QRScanView: View {
    let onScanned: (ScanTarget) -> Void
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = QRScanViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                // Camera preview or permission denied
                Group {
                    switch vm.permissionState {
                    case .notDetermined, .authorized:
                        cameraLayer
                    case .denied, .restricted:
                        permissionDeniedView
                    @unknown default:
                        permissionDeniedView
                    }
                }

                // Scan frame overlay
                scanFrameOverlay

                // Bottom control area
                VStack {
                    Spacer()
                    bottomControls
                        .padding(.bottom, Spacing.xxxl)
                }

                // Success flash
                if vm.didScan {
                    Color.green.opacity(0.25)
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .allowsHitTesting(false)
                }

                // Invalid QR toast (auto-dismiss)
                if vm.showInvalidQRToast {
                    VStack {
                        Spacer()
                        InvalidQRToast()
                            .padding(.horizontal, Spacing.xl)
                            .padding(.bottom, Spacing.xxxl * 2)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    .allowsHitTesting(false)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                        .foregroundColor(.white)
                }
                ToolbarItem(placement: .principal) {
                    Text("扫码进入场景")
                        .font(.spareBodySB)
                        .foregroundColor(.white)
                }
            }
            .toolbarBackground(.clear, for: .navigationBar)
        }
        .onAppear { vm.requestPermission() }
        .onChange(of: vm.scannedCode) { code in
            guard let code, !vm.didScan else { return }
            let target = ScanTarget.parse(from: code)
            // If the QR code doesn't resolve to a valid spare-life scene, show error toast
            if target.sceneID == code && code.hasPrefix("sparelife://") == false
                && URL(string: code)?.scheme != "sparelife" {
                withAnimation(.spareSpring) { vm.showInvalidQRToast = true }
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation(.spareEase) { vm.showInvalidQRToast = false }
                    vm.scannedCode = nil   // allow re-scan
                }
                return
            }
            vm.didScan = true
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                onScanned(target)
            }
        }
    }

    // MARK: - Camera Layer

    private var cameraLayer: some View {
        CameraPreviewRepresentable(session: vm.captureSession)
            .ignoresSafeArea()
    }

    // MARK: - Scan Frame Overlay

    private var scanFrameOverlay: some View {
        GeometryReader { geo in
            let frameSize: CGFloat = min(geo.size.width, geo.size.height) * 0.62
            let centerX = geo.size.width / 2
            let centerY = geo.size.height / 2 - 40   // slightly above center

            ZStack {
                // Dim background except scan window
                Rectangle()
                    .fill(Color.black.opacity(0.55))
                    .ignoresSafeArea()
                    .mask(
                        Rectangle()
                            .ignoresSafeArea()
                            .overlay(
                                RoundedRectangle(cornerRadius: CornerRadius.lg)
                                    .frame(width: frameSize, height: frameSize)
                                    .position(x: centerX, y: centerY)
                                    .blendMode(.destinationOut)
                            )
                    )

                // Corner brackets
                ScanFrameCorners(size: frameSize)
                    .position(x: centerX, y: centerY)

                // Scan line animation
                if vm.permissionState == .authorized {
                    ScanLine(frameSize: frameSize)
                        .position(x: centerX, y: centerY)
                }

                // Hint label
                Text("将「龙虾码」对准框内")
                    .font(.spareCaption)
                    .foregroundColor(.white.opacity(0.8))
                    .position(x: centerX, y: centerY + frameSize / 2 + 24)
            }
        }
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        HStack(spacing: Spacing.xxxl) {
            // Torch toggle
            Button {
                vm.toggleTorch()
            } label: {
                VStack(spacing: Spacing.xs) {
                    Image(systemName: vm.torchOn ? "bolt.fill" : "bolt.slash")
                        .font(.system(size: 24))
                        .foregroundColor(vm.torchOn ? .spareYellow : .white)
                    Text(vm.torchOn ? "关闭" : "手电筒")
                        .font(.spareMicro)
                        .foregroundColor(.white.opacity(0.7))
                }
            }

            // Photo library picker
            Button {
                vm.showPhotoPicker = true
            } label: {
                VStack(spacing: Spacing.xs) {
                    Image(systemName: "photo")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                    Text("相册")
                        .font(.spareMicro)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
    }

    // MARK: - Permission Denied View

    private var permissionDeniedView: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "camera.fill")
                .font(.system(size: 52))
                .foregroundColor(.white.opacity(0.5))

            Text("需要相机权限")
                .font(.spareTitle3)
                .foregroundColor(.white)

            Text("请在系统设置中允许 Spare Life 访问相机，才能扫码进入场景。")
                .font(.spareCaption)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xxxl)

            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("前往设置")
                    .font(.spareBodySB)
                    .foregroundColor(.spareDark)
                    .padding(.horizontal, Spacing.xl)
                    .padding(.vertical, Spacing.md)
                    .background(Color.spareYellow, in: Capsule())
            }
        }
    }
}

// MARK: - Scan Frame Corners

private struct ScanFrameCorners: View {
    let size: CGFloat
    private let stroke: CGFloat = 3
    private let len: CGFloat = 24

    var body: some View {
        ZStack {
            ForEach(Corner.allCases, id: \.self) { corner in
                CornerBracket(size: size, corner: corner, strokeWidth: stroke, armLength: len)
            }
        }
        .frame(width: size, height: size)
    }

    enum Corner: CaseIterable {
        case topLeft, topRight, bottomLeft, bottomRight
    }

    private struct CornerBracket: View {
        let size: CGFloat
        let corner: Corner
        let strokeWidth: CGFloat
        let armLength: CGFloat

        var body: some View {
            Path { path in
                let half = size / 2
                switch corner {
                case .topLeft:
                    path.move(to: CGPoint(x: -half, y: -half + armLength))
                    path.addLine(to: CGPoint(x: -half, y: -half))
                    path.addLine(to: CGPoint(x: -half + armLength, y: -half))
                case .topRight:
                    path.move(to: CGPoint(x: half - armLength, y: -half))
                    path.addLine(to: CGPoint(x: half, y: -half))
                    path.addLine(to: CGPoint(x: half, y: -half + armLength))
                case .bottomLeft:
                    path.move(to: CGPoint(x: -half, y: half - armLength))
                    path.addLine(to: CGPoint(x: -half, y: half))
                    path.addLine(to: CGPoint(x: -half + armLength, y: half))
                case .bottomRight:
                    path.move(to: CGPoint(x: half - armLength, y: half))
                    path.addLine(to: CGPoint(x: half, y: half))
                    path.addLine(to: CGPoint(x: half, y: half - armLength))
                }
            }
            .stroke(Color.spareYellow, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
        }
    }
}

// MARK: - Scan Line Animation

private struct ScanLine: View {
    let frameSize: CGFloat
    /// Drives the animation: false = top, true = bottom.
    @State private var atBottom = false

    private var offsetY: CGFloat {
        let half = frameSize / 2 - 8
        return atBottom ? half : -half
    }

    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [.clear, Color.spareYellow.opacity(0.8), .clear],
                    startPoint: .leading, endPoint: .trailing
                )
            )
            .frame(width: frameSize - 16, height: 2)
            .offset(y: offsetY)
            .animation(
                .linear(duration: 1.8).repeatForever(autoreverses: true),
                value: atBottom
            )
            .onAppear { atBottom = true }
    }
}

// MARK: - Invalid QR Toast

private struct InvalidQRToast: View {
    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "qrcode.viewfinder")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.emotionNegative)
            VStack(alignment: .leading, spacing: 2) {
                Text("不是龙虾码")
                    .font(.spareCaptionSB)
                    .foregroundColor(.white)
                Text("请扫描 Spare Life 场景二维码")
                    .font(.spareMicro)
                    .foregroundColor(.white.opacity(0.7))
            }
            Spacer()
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(Color.spareDark.opacity(0.92), in: RoundedRectangle(cornerRadius: CornerRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .strokeBorder(Color.emotionNegative.opacity(0.4), lineWidth: 1)
        )
    }
}

// MARK: - Camera Preview (UIViewRepresentable)

struct CameraPreviewRepresentable: UIViewRepresentable {
    nonisolated(unsafe) let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}

// MARK: - QRScanViewModel

@MainActor
final class QRScanViewModel: NSObject, ObservableObject, AVCaptureMetadataOutputObjectsDelegate {
    @Published var scannedCode: String? = nil
    @Published var didScan = false
    @Published var torchOn = false
    @Published var showPhotoPicker = false
    @Published var showInvalidQRToast = false
    @Published var permissionState: AVAuthorizationStatus = .notDetermined

    nonisolated(unsafe) let captureSession = AVCaptureSession()
    private var metadataOutput: AVCaptureMetadataOutput?

    func requestPermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        permissionState = status
        switch status {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in
                    self?.permissionState = granted ? .authorized : .denied
                    if granted { self?.startSession() }
                }
            }
        case .authorized:
            startSession()
        default:
            break
        }
    }

    private func startSession() {
        guard !captureSession.isRunning else { return }
        Task.detached { [weak self] in
            guard let self else { return }
            self.captureSession.beginConfiguration()
            guard
                let device = AVCaptureDevice.default(for: .video),
                let input = try? AVCaptureDeviceInput(device: device),
                self.captureSession.canAddInput(input)
            else {
                self.captureSession.commitConfiguration()
                return
            }
            self.captureSession.addInput(input)

            let output = AVCaptureMetadataOutput()
            if self.captureSession.canAddOutput(output) {
                self.captureSession.addOutput(output)
                output.setMetadataObjectsDelegate(self, queue: .main)
                output.metadataObjectTypes = [.qr, .ean8, .ean13, .pdf417, .aztec]
                await MainActor.run { self.metadataOutput = output }
            }
            self.captureSession.commitConfiguration()
            self.captureSession.startRunning()
        }
    }

    nonisolated func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard
            let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
            let code = obj.stringValue
        else { return }
        Task { @MainActor in
            self.scannedCode = code
        }
    }

    func toggleTorch() {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
        try? device.lockForConfiguration()
        torchOn.toggle()
        device.torchMode = torchOn ? .on : .off
        device.unlockForConfiguration()
    }
}

// MARK: - ScanTarget parsing

extension ScanTarget {
    /// Parses a raw string from a QR code/barcode into a ScanTarget.
    /// Scheme: sparelife://scene/{sceneID}?type={type}&name={name}&category={category}
    static func parse(from rawCode: String) -> ScanTarget {
        if let url = URL(string: rawCode),
           url.scheme == "sparelife",
           url.host == "scene",
           let sceneID = url.pathComponents.dropFirst().first {
            let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let params = Dictionary(
                uniqueKeysWithValues: (comps?.queryItems ?? []).compactMap { item in
                    item.value.map { (item.name, $0) }
                }
            )
            let name = params["name"] ?? sceneID
            let categoryRaw = params["category"] ?? ""
            let category = SceneCategory.allCases.first { $0.rawValue == categoryRaw } ?? .all
            let typeRaw = params["type"] ?? "qr"
            let type: ScanTargetType = ScanTargetType(rawValue: typeRaw) ?? .qrCode
            return ScanTarget(
                id: UUID().uuidString,
                sceneID: sceneID,
                type: type,
                displayName: name,
                sceneCategory: category,
                deepLinkURL: url
            )
        }
        // Fallback: treat the raw string as a scene ID
        return ScanTarget(
            id: UUID().uuidString,
            sceneID: rawCode,
            type: .qrCode,
            displayName: "未知场景",
            sceneCategory: .all,
            deepLinkURL: nil
        )
    }
}
