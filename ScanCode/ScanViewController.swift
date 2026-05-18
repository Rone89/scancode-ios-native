import AVFoundation
import UIKit

/// 原生扫码页面。
///
/// 实现点：
/// - 使用 AVFoundation 的 AVCaptureSession / AVCaptureMetadataOutput 识别二维码。
/// - 使用 AVCaptureVideoPreviewLayer 作为相机预览层，不引入第三方扫码库。
/// - 识别成功后，通过 transformedMetadataObject(for:) 获取二维码在预览层中的位置，并绘制绿色边框动画。
/// - 识别成功后触发 UIImpactFeedbackGenerator(style: .medium) 硬件触感反馈。
/// - 支持双指捏合缩放，直接修改 AVCaptureDevice.videoZoomFactor。
/// - 根据二维码内容分发到微信、支付宝或系统弹窗选择支付方式。
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
    private let sessionQueue = DispatchQueue(label: "com.example.scancode.capture-session")

    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var captureDevice: AVCaptureDevice?
    private var scanState: ScanState = .idle
    private var initialZoomFactor: CGFloat = 1

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

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "扫码"
        view.backgroundColor = .black
        hapticFeedback.prepare()
        configurePreviewLayer()
        configurePinchGesture()
        requestCameraPermissionAndStart()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        previewLayer?.frame = view.bounds
        updatePreviewOrientation()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        scanState = .idle
        hideQRCodeBorder()
        startScanningIfPossible()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        stopScanning()
    }

    deinit {
        stopScanning()
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

            if self.captureSession.inputs.isEmpty && self.captureSession.outputs.isEmpty {
                self.configureCaptureSession()
            }

            self.startScanningIfPossible()
        }
    }

    func configureCaptureSession() {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .high
        defer { captureSession.commitConfiguration() }

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            DispatchQueue.main.async { [weak self] in
                self?.showSimpleAlert(title: "无法使用相机", message: "当前设备没有可用的后置摄像头。")
            }
            return
        }

        captureDevice = device

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

        let metadataOutput = AVCaptureMetadataOutput()
        guard captureSession.canAddOutput(metadataOutput) else {
            DispatchQueue.main.async { [weak self] in
                self?.showSimpleAlert(title: "扫码初始化失败", message: "无法添加二维码识别输出。")
            }
            return
        }

        captureSession.addOutput(metadataOutput)
        metadataOutput.setMetadataObjectsDelegate(self, queue: .main)

        if metadataOutput.availableMetadataObjectTypes.contains(.qr) {
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.showSimpleAlert(title: "扫码不可用", message: "当前设备不支持二维码识别。")
            }
        }
    }

    func startScanningIfPossible() {
        sessionQueue.async { [weak self] in
            guard
                let self,
                AVCaptureDevice.authorizationStatus(for: .video) == .authorized,
                !self.captureSession.inputs.isEmpty,
                !self.captureSession.outputs.isEmpty,
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
        sessionQueue.async { [weak self] in
            guard let self, self.captureSession.isRunning else { return }
            self.captureSession.stopRunning()
        }
    }

    func resumeScanningAfterResultHandling() {
        scanState = .idle
        hideQRCodeBorder()
        startScanningIfPossible()
        hapticFeedback.prepare()
    }

    func updatePreviewOrientation() {
        guard let connection = previewLayer?.connection, connection.isVideoOrientationSupported else { return }

        switch view.window?.windowScene?.interfaceOrientation {
        case .portrait:
            connection.videoOrientation = .portrait
        case .portraitUpsideDown:
            connection.videoOrientation = .portraitUpsideDown
        case .landscapeLeft:
            connection.videoOrientation = .landscapeLeft
        case .landscapeRight:
            connection.videoOrientation = .landscapeRight
        default:
            connection.videoOrientation = .portrait
        }
    }
}

// MARK: - Metadata Output

extension ScanViewController: AVCaptureMetadataOutputObjectsDelegate {

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard scanState == .idle else { return }
        guard
            let metadataObject = metadataObjects.first(where: { $0.type == .qr }) as? AVMetadataMachineReadableCodeObject,
            let qrCodeString = metadataObject.stringValue
        else {
            return
        }

        scanState = .handlingResult
        pauseScanningForResultHandling()

        // transformedMetadataObject(for:) 会把 AVFoundation 识别到的二维码坐标，
        // 转换成 AVCaptureVideoPreviewLayer 当前显示坐标系中的位置。
        // 这里使用转换后的对象绘制绿色边框，保证边框与预览画面中的二维码位置一致。
        if let transformedObject = previewLayer?.transformedMetadataObject(for: metadataObject) {
            showQRCodeBorder(around: transformedObject.bounds)
        }

        hapticFeedback.impactOccurred()
        handleScannedQRCodeString(qrCodeString)
    }
}

// MARK: - QR Code Border Animation

private extension ScanViewController {

    func showQRCodeBorder(around bounds: CGRect) {
        let path = UIBezierPath(roundedRect: bounds.insetBy(dx: -4, dy: -4), cornerRadius: 8)
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

        case .changed:
            let requestedZoomFactor = initialZoomFactor * gesture.scale
            setVideoZoomFactor(requestedZoomFactor, on: device)

        default:
            break
        }
    }

    func setVideoZoomFactor(_ zoomFactor: CGFloat, on device: AVCaptureDevice) {
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }

            // videoZoomFactor 的合法范围由设备决定。
            // 为了避免用户双指缩放时突然放大过多，这里把上限控制在系统最大值与 6 倍之间的较小值。
            let maxZoomFactor = min(device.activeFormat.videoMaxZoomFactor, 6)
            let clampedZoomFactor = min(max(zoomFactor, 1), maxZoomFactor)
            device.videoZoomFactor = clampedZoomFactor
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
            openWeChat(for: qrCodeString)

        case .alipay:
            openAlipayQRCode(qrCodeString)

        case .general:
            showGeneralQRCodeActionSheet(for: qrCodeString)
        }
    }

    private func route(for qrCodeString: String) -> PaymentRoute {
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
            || lowercasedString.contains("wxp://")
            || lowercasedString.contains("weixin://")
            || lowercasedString.contains("wechat://")
    }

    func isAlipayQRCode(_ lowercasedString: String) -> Bool {
        lowercasedString.contains("alipay.com")
            || lowercasedString.contains("qr.alipay.com")
            || lowercasedString.contains("alipayqr://")
            || lowercasedString.contains("alipays://")
    }

    func showGeneralQRCodeActionSheet(for qrCodeString: String) {
        let alert = UIAlertController(
            title: "请选择支付方式",
            message: qrCodeString,
            preferredStyle: .actionSheet
        )

        // 聚合支付码无法仅靠本 App 判断最终收款方。
        // 用户选择“微信支付”后，这里只负责拉起微信/微信扫一扫，让微信自行继续处理。
        alert.addAction(UIAlertAction(title: "微信支付", style: .default) { [weak self] _ in
            self?.openWeChat(for: qrCodeString)
        })

        // 用户选择“支付宝支付”后，将原始聚合码作为 qrcode 参数交给支付宝。
        // 支付宝客户端会解析 qrcode 中的真实业务地址，并进入对应支付流程。
        alert.addAction(UIAlertAction(title: "支付宝支付", style: .default) { [weak self] _ in
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

    func openWeChat(for qrCodeString: String) {
        // 微信二维码的业务形态很多：
        // - weixin.qq.com 可能是微信网页/业务二维码；
        // - wxp://、weixin:// 这类内容更接近微信私有 Scheme；
        // - 聚合支付码选择微信支付时，通常需要拉起微信或微信扫一扫继续处理。
        //
        // iOS 不允许第三方 App 直接控制微信完成扫一扫后的支付链路。
        // 因此这里按“尽最大努力”策略：
        // 1. 如果二维码本身就是微信可打开的私有 Scheme，优先打开原始内容；
        // 2. 否则尝试打开微信扫一扫 Scheme；
        // 3. 再退回到 weixin:// 拉起微信首页。
        //
        // 注意：如果原始二维码是 https://weixin.qq.com/...，
        // 不要把它作为第一个候选 URL，否则系统可能会直接用 Safari 打开网页，
        // 这与“尝试拉起微信”的业务目标不一致。
        var candidates: [URL] = []
        if let originalURL = URL(string: qrCodeString),
           let scheme = originalURL.scheme?.lowercased(),
           ["weixin", "wxp", "wechat"].contains(scheme) {
            candidates.append(originalURL)
        }
        candidates.append(contentsOf: [
            URL(string: "weixin://scanqrcode"),
            URL(string: "weixin://")
        ].compactMap { $0 })

        openFirstAvailableURL(
            candidates,
            failureTitle: "无法打开微信",
            failureMessage: "请确认已安装微信，并在 Info.plist 中配置 weixin / wechat / wxp 白名单。"
        )
    }

    func openAlipayQRCode(_ qrCodeString: String) {
        if qrCodeString.lowercased().hasPrefix("alipayqr://") || qrCodeString.lowercased().hasPrefix("alipays://") {
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
        // alipayqr://platformapi/startapp?saId=10000007&qrcode=【编码后的URL】
        //
        // 关键点：
        // - qrcode 参数必须放入“原始二维码内容”；
        // - 原始内容里通常包含 : / ? & = 等特殊字符，必须先做 URL Query Percent Encoding；
        // - saId=10000007 表示调用支付宝客户端的扫码/二维码解析能力；
        // - 使用 UIApplication.shared.open 后，后续支付页由支付宝 App 自行解析并展示。
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
        // 这里编码的是 qrcode= 后面的“参数值”，不是整段 URL。
        // CharacterSet.urlQueryAllowed 对参数值来说过于宽松，可能保留 &、=、? 等字符，
        // 导致原始二维码 URL 被错误拆成多个查询参数。
        // 因此只保留 RFC 3986 的 unreserved 字符，其余字符全部百分号编码。
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        return value.addingPercentEncoding(withAllowedCharacters: allowedCharacters)
    }

    func openFirstAvailableURL(_ urls: [URL], failureTitle: String, failureMessage: String) {
        guard let url = urls.first else {
            showOpenFailureAlert(title: failureTitle, message: failureMessage)
            return
        }

        // canOpenURL 需要 Info.plist 的 LSApplicationQueriesSchemes 白名单配合。
        // 如果没有配置白名单，canOpenURL 会返回 false，即使用户手机里已经安装对应 App。
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:]) { [weak self] success in
                DispatchQueue.main.async {
                    if success {
                        self?.resumeScanningAfterResultHandling()
                    } else {
                        self?.openFirstAvailableURL(
                            Array(urls.dropFirst()),
                            failureTitle: failureTitle,
                            failureMessage: failureMessage
                        )
                    }
                }
            }
        } else {
            openFirstAvailableURL(Array(urls.dropFirst()), failureTitle: failureTitle, failureMessage: failureMessage)
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
}
