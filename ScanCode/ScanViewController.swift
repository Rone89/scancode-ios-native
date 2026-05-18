import AVFoundation
import CoreMedia
import QuartzCore
import UIKit

/// 原生扫码控制器。
///
/// 设计原则：
/// - 首屏只显示系统相机预览，不叠加额外提示卡片或快捷按钮。
/// - 使用 AVFoundation 原生识别二维码。
/// - 识别成功后绘制绿色边框动画，并触发系统触感反馈。
/// - 按二维码类型执行微信、支付宝或通用分发逻辑。
/// - 通过后台串行队列、30fps 帧率限制和及时停流降低发热。
final class ScanViewController: UIViewController {

    private enum ScanState {
        case idle
        case handlingResult
    }

    private enum PaymentRoute {
        case weChat
        case alipay
        case general
    }

    private let captureSession = AVCaptureSession()
    private let metadataOutput = AVCaptureMetadataOutput()
    private let sessionQueue = DispatchQueue(label: "com.codex.scancode.capture-session", qos: .userInitiated)
    private let metadataOutputQueue = DispatchQueue(label: "com.codex.scancode.metadata-output", qos: .userInitiated)
    private let stateLock = NSLock()

    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var captureDevice: AVCaptureDevice?
    private var scanState: ScanState = .idle
    private var isSessionConfigured = false
    private var initialZoomFactor: CGFloat = 1
    private var lastAppliedZoomFactor: CGFloat = 1
    private var lastHandledPayload = ""
    private var lastHandledTimestamp: CFTimeInterval = 0

    private let qrCodeBorderLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.strokeColor = UIColor.systemGreen.cgColor
        layer.fillColor = UIColor.clear.cgColor
        layer.lineWidth = 4
        layer.lineJoin = .round
        layer.lineCap = .round
        layer.opacity = 0
        return layer
    }()

    private let hapticFeedback = UIImpactFeedbackGenerator(style: .medium)

    override var preferredStatusBarStyle: UIStatusBarStyle {
        .lightContent
    }

    override var prefersStatusBarHidden: Bool {
        true
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .black
        view.clipsToBounds = true
        hapticFeedback.prepare()

        configurePreviewLayer()
        configurePinchGesture()
        installLifecycleObservers()
        requestCameraPermissionAndStart()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        previewLayer?.frame = view.bounds
        updatePreviewOrientation()
        updateRectOfInterest()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        resumeScanningAfterResultHandling()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopScanning()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        stopScanning()
    }

    func handleExternalAction(_ action: ScanAppAction) {
        switch action {
        case .scanner:
            resumeScanningAfterResultHandling()
        case .weChatScanner:
            openWeChatScanner()
        case .alipayScanner:
            openAlipayScanner()
        }
    }
}

// MARK: - Camera Permission

private extension ScanViewController {

    func requestCameraPermissionAndStart() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureCaptureSessionAndStart()

        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.configureCaptureSessionAndStart()
                    } else {
                        self?.showCameraPermissionAlert()
                    }
                }
            }

        case .denied, .restricted:
            showCameraPermissionAlert()

        @unknown default:
            showCameraPermissionAlert()
        }
    }

    func showCameraPermissionAlert() {
        let alert = UIAlertController(
            title: "无法访问相机",
            message: "请在系统设置中允许访问相机后再扫码。",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "去设置", style: .default) { _ in
            guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
            UIApplication.shared.open(settingsURL)
        })

        present(alert, animated: true)
    }
}

// MARK: - App Lifecycle

private extension ScanViewController {

    func installLifecycleObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleApplicationDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleApplicationWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }

    @objc func handleApplicationDidEnterBackground() {
        stopScanning()
    }

    @objc func handleApplicationWillEnterForeground() {
        guard isViewLoaded, view.window != nil else { return }
        resumeScanningAfterResultHandling()
    }
}

// MARK: - Capture Session

private extension ScanViewController {

    func configurePreviewLayer() {
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds

        view.layer.insertSublayer(previewLayer, at: 0)
        previewLayer.addSublayer(qrCodeBorderLayer)
        self.previewLayer = previewLayer
    }

    func configureCaptureSessionAndStart() {
        sessionQueue.async { [weak self] in
            guard let self else { return }

            if !self.isSessionConfigured {
                self.configureCaptureSession()
            }

            self.startScanningIfPossible()
        }
    }

    func configureCaptureSession() {
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }

        // 扫码不需要 4K 级别分辨率，优先选择更省电的 .high 预设。
        if captureSession.canSetSessionPreset(.high) {
            captureSession.sessionPreset = .high
        }

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            DispatchQueue.main.async { [weak self] in
                self?.showSimpleAlert(title: "无法使用相机", message: "当前设备没有可用的后置摄像头。")
            }
            return
        }

        captureDevice = device
        configureDeviceForLowerThermals(device)

        do {
            let input = try AVCaptureDeviceInput(device: device)
            guard captureSession.canAddInput(input) else {
                DispatchQueue.main.async { [weak self] in
                    self?.showSimpleAlert(title: "相机初始化失败", message: "无法添加相机输入。")
                }
                return
            }
            captureSession.addInput(input)
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.showSimpleAlert(title: "相机初始化失败", message: error.localizedDescription)
            }
            return
        }

        guard captureSession.canAddOutput(metadataOutput) else {
            DispatchQueue.main.async { [weak self] in
                self?.showSimpleAlert(title: "扫码初始化失败", message: "无法添加二维码识别输出。")
            }
            return
        }

        captureSession.addOutput(metadataOutput)
        metadataOutput.setMetadataObjectsDelegate(self, queue: metadataOutputQueue)

        guard metadataOutput.availableMetadataObjectTypes.contains(.qr) else {
            DispatchQueue.main.async { [weak self] in
                self?.showSimpleAlert(title: "扫码不可用", message: "当前设备不支持二维码识别。")
            }
            return
        }

        metadataOutput.metadataObjectTypes = [.qr]
        isSessionConfigured = true

        DispatchQueue.main.async { [weak self] in
            self?.updateRectOfInterest()
        }
    }

    func configureDeviceForLowerThermals(_ device: AVCaptureDevice) {
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }

            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }

            if device.isAutoFocusRangeRestrictionSupported {
                device.autoFocusRangeRestriction = .near
            }

            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }

            if device.isSmoothAutoFocusSupported {
                device.isSmoothAutoFocusEnabled = true
            }

            device.isSubjectAreaChangeMonitoringEnabled = false

            let targetFrameRate = 30.0
            let frameDuration = CMTime(value: 1, timescale: 30)
            let supportsFrameRate = device.activeFormat.videoSupportedFrameRateRanges.contains {
                $0.minFrameRate <= targetFrameRate && targetFrameRate <= $0.maxFrameRate
            }

            if supportsFrameRate {
                device.activeVideoMinFrameDuration = frameDuration
                device.activeVideoMaxFrameDuration = frameDuration
            }

            if device.videoZoomFactor != 1 {
                device.videoZoomFactor = 1
            }
        } catch {
            print("Failed to configure capture device: \(error)")
        }
    }

    func startScanningIfPossible() {
        sessionQueue.async { [weak self] in
            guard
                let self,
                self.isSessionConfigured,
                AVCaptureDevice.authorizationStatus(for: .video) == .authorized,
                !self.captureSession.isRunning
            else {
                return
            }

            self.captureSession.startRunning()
        }
    }

    func stopScanning() {
        sessionQueue.async { [weak self] in
            guard let self, self.captureSession.isRunning else { return }
            self.captureSession.stopRunning()
        }
    }

    func pauseScanningForResultHandling() {
        stopScanning()
    }

    func resumeScanningAfterResultHandling() {
        resetScanState()
        hideQRCodeBorder()
        startScanningIfPossible()
        hapticFeedback.prepare()
    }

    func beginManualRouting() {
        stateLock.lock()
        scanState = .handlingResult
        lastHandledTimestamp = CACurrentMediaTime()
        stateLock.unlock()

        hideQRCodeBorder()
        pauseScanningForResultHandling()
    }

    func updatePreviewOrientation() {
        guard let connection = previewLayer?.connection else { return }

        let interfaceOrientation = view.window?.windowScene?.interfaceOrientation ?? .portrait
        let rotationAngle: CGFloat

        switch interfaceOrientation {
        case .portrait:
            rotationAngle = 90
        case .portraitUpsideDown:
            rotationAngle = 270
        case .landscapeLeft:
            rotationAngle = 0
        case .landscapeRight:
            rotationAngle = 180
        default:
            rotationAngle = 90
        }

        if connection.isVideoRotationAngleSupported(rotationAngle) {
            connection.videoRotationAngle = rotationAngle
        }
    }

    func updateRectOfInterest() {
        guard let previewLayer else { return }

        // 扫码页没有额外的可视化取景框，因此识别区域直接放开到全屏，
        // 避免用户把二维码移到边缘时看得到却扫不到。
        metadataOutput.rectOfInterest = previewLayer.metadataOutputRectConverted(fromLayerRect: view.bounds)
    }
}

// MARK: - Metadata Output

extension ScanViewController: AVCaptureMetadataOutputObjectsDelegate {

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard
            let metadataObject = metadataObjects.first(where: { $0.type == .qr }) as? AVMetadataMachineReadableCodeObject,
            let qrCodeString = metadataObject.stringValue,
            markScanHandlingBegan(for: qrCodeString)
        else {
            return
        }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            self.pauseScanningForResultHandling()

            // transformedMetadataObject(for:) 会把 AVFoundation 识别到的二维码坐标，
            // 转换到当前 AVCaptureVideoPreviewLayer 的显示坐标系中，
            // 这样绿色边框动画才能准确贴合到实际二维码位置。
            if let transformedObject = self.previewLayer?.transformedMetadataObject(for: metadataObject) {
                self.showQRCodeBorder(around: transformedObject.bounds)
            }

            self.hapticFeedback.impactOccurred()
            self.handleScannedQRCodeString(qrCodeString)
        }
    }
}

// MARK: - QR Border

private extension ScanViewController {

    func showQRCodeBorder(around bounds: CGRect) {
        let path = UIBezierPath(roundedRect: bounds.insetBy(dx: -4, dy: -4), cornerRadius: 10)
        qrCodeBorderLayer.path = path.cgPath

        let fadeIn = CABasicAnimation(keyPath: "opacity")
        fadeIn.fromValue = 0
        fadeIn.toValue = 1
        fadeIn.duration = 0.12
        fadeIn.timingFunction = CAMediaTimingFunction(name: .easeOut)

        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 1.08
        scale.toValue = 1
        scale.duration = 0.18
        scale.timingFunction = CAMediaTimingFunction(name: .easeOut)

        let group = CAAnimationGroup()
        group.animations = [fadeIn, scale]
        group.duration = 0.18
        group.isRemovedOnCompletion = true

        qrCodeBorderLayer.opacity = 1
        qrCodeBorderLayer.add(group, forKey: "qr-border-success")
    }

    func hideQRCodeBorder() {
        qrCodeBorderLayer.removeAllAnimations()
        qrCodeBorderLayer.opacity = 0
        qrCodeBorderLayer.path = nil
    }
}

// MARK: - Pinch Zoom

private extension ScanViewController {

    func configurePinchGesture() {
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinchGesture(_:)))
        view.addGestureRecognizer(pinchGesture)
    }

    @objc func handlePinchGesture(_ gesture: UIPinchGestureRecognizer) {
        guard let device = captureDevice else { return }

        switch gesture.state {
        case .began:
            initialZoomFactor = device.videoZoomFactor
            lastAppliedZoomFactor = device.videoZoomFactor

        case .changed:
            let requestedZoomFactor = initialZoomFactor * gesture.scale
            guard abs(requestedZoomFactor - lastAppliedZoomFactor) > 0.02 else { return }
            setVideoZoomFactor(requestedZoomFactor, on: device)

        default:
            break
        }
    }

    func setVideoZoomFactor(_ zoomFactor: CGFloat, on device: AVCaptureDevice) {
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }

            let maxZoomFactor = min(device.activeFormat.videoMaxZoomFactor, 6)
            let clampedZoomFactor = min(max(zoomFactor, 1), maxZoomFactor)
            device.videoZoomFactor = clampedZoomFactor
            lastAppliedZoomFactor = clampedZoomFactor
        } catch {
            print("Failed to set video zoom factor: \(error)")
        }
    }
}

// MARK: - Routing

private extension ScanViewController {

    func handleScannedQRCodeString(_ qrCodeString: String) {
        switch route(for: qrCodeString) {
        case .weChat:
            openWeChatScanner()

        case .alipay:
            openAlipayQRCode(qrCodeString)

        case .general:
            showGeneralQRCodeActionSheet(for: qrCodeString)
        }
    }

    func route(for qrCodeString: String) -> PaymentRoute {
        let lowercasedString = qrCodeString.lowercased()

        if isWeChatQRCode(lowercasedString) {
            return .weChat
        }

        if isAlipayQRCode(lowercasedString) {
            return .alipay
        }

        return .general
    }

    func isWeChatQRCode(_ lowercasedString: String) -> Bool {
        lowercasedString.contains("weixin.qq.com")
            || lowercasedString.contains("wx.tenpay.com")
            || lowercasedString.contains("wxp://")
            || lowercasedString.contains("weixin://")
            || lowercasedString.contains("wechat://")
    }

    func isAlipayQRCode(_ lowercasedString: String) -> Bool {
        lowercasedString.contains("alipay.com")
            || lowercasedString.contains("qr.alipay.com")
            || lowercasedString.contains("ds.alipay.com")
            || lowercasedString.contains("alipayqr://")
            || lowercasedString.contains("alipays://")
    }

    func showGeneralQRCodeActionSheet(for qrCodeString: String) {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

        alert.addAction(UIAlertAction(title: "微信", style: .default) { [weak self] _ in
            self?.openWeChatScanner()
        })

        alert.addAction(UIAlertAction(title: "支付宝", style: .default) { [weak self] _ in
            self?.openAlipayQRCode(qrCodeString)
        })

        alert.addAction(UIAlertAction(title: "取消", style: .cancel) { [weak self] _ in
            self?.resumeScanningAfterResultHandling()
        })

        if let popoverPresentationController = alert.popoverPresentationController {
            popoverPresentationController.sourceView = view
            popoverPresentationController.sourceRect = CGRect(
                x: view.bounds.midX,
                y: view.bounds.midY,
                width: 0,
                height: 0
            )
            popoverPresentationController.permittedArrowDirections = []
        }

        present(alert, animated: true)
    }

    func openWeChatScanner() {
        beginManualRouting()

        // 微信相关二维码的业务要求是：
        // 只要识别到它属于微信体系，就直接拉起微信扫一扫，不再二次确认。
        openFirstAvailableURL(
            weChatScannerCandidates(),
            failureTitle: "无法打开微信扫一扫",
            failureMessage: "请确认已安装微信，并在 Info.plist 中配置 weixin / wechat / wxp 白名单。"
        )
    }

    func weChatScannerCandidates() -> [URL] {
        [
            URL(string: "weixin://scanqrcode"),
            URL(string: "weixin://dl/scan"),
            URL(string: "weixin://")
        ].compactMap { $0 }
    }

    func openAlipayScanner() {
        beginManualRouting()

        let scannerURLs = [
            URL(string: "alipayqr://platformapi/startapp?saId=10000007"),
            URL(string: "alipays://platformapi/startapp?appId=10000007")
        ].compactMap { $0 }

        openFirstAvailableURL(
            scannerURLs,
            failureTitle: "无法打开支付宝扫码",
            failureMessage: "请确认已安装支付宝，并在 Info.plist 中配置 alipayqr / alipays 白名单。"
        )
    }

    func openAlipayQRCode(_ qrCodeString: String) {
        let lowercasedString = qrCodeString.lowercased()

        if lowercasedString.hasPrefix("alipayqr://") || lowercasedString.hasPrefix("alipays://") {
            guard let directURL = URL(string: qrCodeString) else {
                showOpenFailureAlert(title: "无法打开支付宝", message: "二维码内容不是有效的支付宝链接。")
                return
            }

            openFirstAvailableURL(
                [directURL],
                failureTitle: "无法打开支付宝",
                failureMessage: "请确认已安装支付宝，并在 Info.plist 中配置 alipayqr / alipays 白名单。"
            )
            return
        }

        // 支付宝开放标准 Scheme：
        // alipayqr://platformapi/startapp?saId=10000007&qrcode=【编码后的原始二维码内容】
        //
        // 关键点：
        // 1. qrcode 参数必须传原始扫码结果；
        // 2. 原始内容里通常会包含 ?、&、=、/ 等字符，必须先做 URL Query 编码；
        // 3. 编码后再交给 UIApplication.shared.open，由支付宝客户端继续解析具体页面。
        guard let encodedQRCode = percentEncodedQueryValue(qrCodeString) else {
            showOpenFailureAlert(title: "无法打开支付宝", message: "二维码内容编码失败。")
            return
        }

        let schemeString = "alipayqr://platformapi/startapp?saId=10000007&qrcode=\(encodedQRCode)"
        guard let alipayURL = URL(string: schemeString) else {
            showOpenFailureAlert(title: "无法打开支付宝", message: "支付宝跳转链接生成失败。")
            return
        }

        openFirstAvailableURL(
            [alipayURL],
            failureTitle: "无法打开支付宝",
            failureMessage: "请确认已安装支付宝，并在 Info.plist 中配置 alipayqr / alipays 白名单。"
        )
    }

    func percentEncodedQueryValue(_ value: String) -> String? {
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        return value.addingPercentEncoding(withAllowedCharacters: allowedCharacters)
    }

    func openFirstAvailableURL(_ urls: [URL], failureTitle: String, failureMessage: String) {
        guard let url = urls.first else {
            showOpenFailureAlert(title: failureTitle, message: failureMessage)
            return
        }

        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:]) { [weak self] success in
                DispatchQueue.main.async {
                    guard let self else { return }

                    if success {
                        self.hideQRCodeBorder()
                    } else {
                        self.openFirstAvailableURL(
                            Array(urls.dropFirst()),
                            failureTitle: failureTitle,
                            failureMessage: failureMessage
                        )
                    }
                }
            }
        } else {
            openFirstAvailableURL(
                Array(urls.dropFirst()),
                failureTitle: failureTitle,
                failureMessage: failureMessage
            )
        }
    }

    func showOpenFailureAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default) { [weak self] _ in
            self?.resumeScanningAfterResultHandling()
        })
        present(alert, animated: true)
    }

    func showSimpleAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }

    func markScanHandlingBegan(for payload: String) -> Bool {
        stateLock.lock()
        defer { stateLock.unlock() }

        let now = CACurrentMediaTime()
        let duplicateCooldown: CFTimeInterval = 1.25

        guard scanState == .idle else { return false }
        guard payload != lastHandledPayload || now - lastHandledTimestamp > duplicateCooldown else { return false }

        scanState = .handlingResult
        lastHandledPayload = payload
        lastHandledTimestamp = now
        return true
    }

    func resetScanState() {
        stateLock.lock()
        defer { stateLock.unlock() }
        scanState = .idle
    }
}
