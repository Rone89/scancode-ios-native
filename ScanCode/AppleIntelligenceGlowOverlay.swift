import QuartzCore
import UIKit

final class AppleIntelligenceGlowOverlayView: UIView {

    private let outerGlowLayer = CAGradientLayer()
    private let innerGlowLayer = CAGradientLayer()
    private let highlightLayer = CAGradientLayer()
    private let outerGlowMask = CAShapeLayer()
    private let innerGlowMask = CAShapeLayer()
    private let highlightMask = CAShapeLayer()
    private let topSheenLayer = CAGradientLayer()
    private let bottomSheenLayer = CAGradientLayer()
    private let leadingSheenLayer = CAGradientLayer()
    private let trailingSheenLayer = CAGradientLayer()

    private var reduceMotion: Bool {
        UIAccessibility.isReduceMotionEnabled
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureView()
        configureGlowLayers()
        configureSheenLayers()
        installReduceMotionObserver()
        updateMotionState()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureView()
        configureGlowLayers()
        configureSheenLayers()
        installReduceMotionObserver()
        updateMotionState()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateLayerFrames()
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        false
    }
}

private extension AppleIntelligenceGlowOverlayView {

    func configureView() {
        backgroundColor = .clear
        isOpaque = false
        isUserInteractionEnabled = false
        clipsToBounds = true
    }

    func configureGlowLayers() {
        configureConicGlowLayer(outerGlowLayer)
        configureConicGlowLayer(innerGlowLayer)
        configureConicGlowLayer(highlightLayer)

        outerGlowLayer.colors = glowColors(alphaScale: 0.34)
        innerGlowLayer.colors = glowColors(alphaScale: 0.48)
        highlightLayer.colors = highlightColors()

        outerGlowLayer.locations = numberValues([0.00, 0.10, 0.28, 0.46, 0.66, 0.82, 1.00])
        innerGlowLayer.locations = outerGlowLayer.locations
        highlightLayer.locations = numberValues([0.00, 0.08, 0.16, 0.31, 0.64, 1.00])

        outerGlowLayer.mask = outerGlowMask
        innerGlowLayer.mask = innerGlowMask
        highlightLayer.mask = highlightMask

        layer.addSublayer(outerGlowLayer)
        layer.addSublayer(innerGlowLayer)
        layer.addSublayer(highlightLayer)
    }

    func configureConicGlowLayer(_ layer: CAGradientLayer) {
        layer.type = .conic
        layer.startPoint = CGPoint(x: 0.5, y: 0.5)
        layer.endPoint = CGPoint(x: 1, y: 0.5)
        layer.backgroundColor = UIColor.clear.cgColor
        layer.isOpaque = false
    }

    func configureSheenLayers() {
        configureHorizontalSheenLayer(topSheenLayer)
        configureHorizontalSheenLayer(bottomSheenLayer)
        configureVerticalSheenLayer(leadingSheenLayer)
        configureVerticalSheenLayer(trailingSheenLayer)

        layer.addSublayer(topSheenLayer)
        layer.addSublayer(bottomSheenLayer)
        layer.addSublayer(leadingSheenLayer)
        layer.addSublayer(trailingSheenLayer)
    }

    func configureHorizontalSheenLayer(_ layer: CAGradientLayer) {
        layer.startPoint = CGPoint(x: 0, y: 0.5)
        layer.endPoint = CGPoint(x: 1, y: 0.5)
        layer.colors = [
            UIColor.clear.cgColor,
            UIColor.white.withAlphaComponent(0.12).cgColor,
            UIColor(red: 0.58, green: 0.91, blue: 1.00, alpha: 0.08).cgColor,
            UIColor(red: 1.00, green: 0.60, blue: 0.92, alpha: 0.07).cgColor,
            UIColor.clear.cgColor
        ]
        layer.locations = numberValues([0.00, 0.24, 0.46, 0.68, 1.00])
        layer.backgroundColor = UIColor.clear.cgColor
        layer.isOpaque = false
    }

    func configureVerticalSheenLayer(_ layer: CAGradientLayer) {
        layer.startPoint = CGPoint(x: 0.5, y: 0)
        layer.endPoint = CGPoint(x: 0.5, y: 1)
        layer.colors = [
            UIColor.clear.cgColor,
            UIColor.white.withAlphaComponent(0.10).cgColor,
            UIColor(red: 0.62, green: 1.00, blue: 0.86, alpha: 0.07).cgColor,
            UIColor(red: 0.82, green: 0.56, blue: 1.00, alpha: 0.06).cgColor,
            UIColor.clear.cgColor
        ]
        layer.locations = numberValues([0.00, 0.22, 0.48, 0.70, 1.00])
        layer.backgroundColor = UIColor.clear.cgColor
        layer.isOpaque = false
    }

    func installReduceMotionObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleReduceMotionStatusChanged),
            name: UIAccessibility.reduceMotionStatusDidChangeNotification,
            object: nil
        )
    }

    @objc func handleReduceMotionStatusChanged() {
        updateMotionState()
    }

    func updateLayerFrames() {
        let currentBounds = bounds
        guard !currentBounds.isEmpty else { return }

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        outerGlowLayer.frame = currentBounds
        innerGlowLayer.frame = currentBounds
        highlightLayer.frame = currentBounds

        updateMask(outerGlowMask, lineWidth: max(30, min(currentBounds.width, currentBounds.height) * 0.07))
        updateMask(innerGlowMask, lineWidth: max(14, min(currentBounds.width, currentBounds.height) * 0.032))
        updateMask(highlightMask, lineWidth: max(2, min(currentBounds.width, currentBounds.height) * 0.006))

        let horizontalHeight = max(18, currentBounds.height * 0.035)
        let verticalWidth = max(18, currentBounds.width * 0.045)

        topSheenLayer.frame = CGRect(x: 0, y: 0, width: currentBounds.width, height: horizontalHeight)
        bottomSheenLayer.frame = CGRect(
            x: 0,
            y: currentBounds.height - horizontalHeight,
            width: currentBounds.width,
            height: horizontalHeight
        )
        leadingSheenLayer.frame = CGRect(x: 0, y: 0, width: verticalWidth, height: currentBounds.height)
        trailingSheenLayer.frame = CGRect(
            x: currentBounds.width - verticalWidth,
            y: 0,
            width: verticalWidth,
            height: currentBounds.height
        )

        CATransaction.commit()
    }

    func updateMask(_ mask: CAShapeLayer, lineWidth: CGFloat) {
        let insetBounds = bounds.insetBy(dx: lineWidth / 2, dy: lineWidth / 2)
        let cornerRadius = max(34, min(bounds.width, bounds.height) * 0.09)
        let path = UIBezierPath(roundedRect: insetBounds, cornerRadius: cornerRadius)

        mask.path = path.cgPath
        mask.fillColor = UIColor.clear.cgColor
        mask.strokeColor = UIColor.black.cgColor
        mask.lineWidth = lineWidth
        mask.lineJoin = .round
        mask.lineCap = .round
    }

    func updateMotionState() {
        removeAnimations()

        if reduceMotion {
            outerGlowLayer.opacity = 0.16
            innerGlowLayer.opacity = 0.18
            highlightLayer.opacity = 0.20
            setSheenOpacity(0.05)
        } else {
            outerGlowLayer.opacity = 0.24
            innerGlowLayer.opacity = 0.28
            highlightLayer.opacity = 0.34
            setSheenOpacity(1)
            addAnimations()
        }
    }

    func removeAnimations() {
        [
            outerGlowLayer,
            innerGlowLayer,
            highlightLayer,
            topSheenLayer,
            bottomSheenLayer,
            leadingSheenLayer,
            trailingSheenLayer
        ].forEach { $0.removeAllAnimations() }
    }

    func setSheenOpacity(_ opacity: Float) {
        topSheenLayer.opacity = opacity
        bottomSheenLayer.opacity = opacity
        leadingSheenLayer.opacity = opacity
        trailingSheenLayer.opacity = opacity
    }

    func addAnimations() {
        outerGlowLayer.add(rotationAnimation(duration: 12, clockwise: true), forKey: "outer-glow-rotation")
        innerGlowLayer.add(rotationAnimation(duration: 18, clockwise: false), forKey: "inner-glow-rotation")
        highlightLayer.add(rotationAnimation(duration: 9, clockwise: true), forKey: "highlight-rotation")

        topSheenLayer.add(opacityAnimation(begin: 0.0), forKey: "top-sheen-opacity")
        trailingSheenLayer.add(opacityAnimation(begin: 0.6), forKey: "trailing-sheen-opacity")
        bottomSheenLayer.add(opacityAnimation(begin: 1.2), forKey: "bottom-sheen-opacity")
        leadingSheenLayer.add(opacityAnimation(begin: 1.8), forKey: "leading-sheen-opacity")
    }

    func rotationAnimation(duration: CFTimeInterval, clockwise: Bool) -> CABasicAnimation {
        let animation = CABasicAnimation(keyPath: "transform.rotation.z")
        animation.fromValue = clockwise ? 0 : Double.pi * 2
        animation.toValue = clockwise ? Double.pi * 2 : 0
        animation.duration = duration
        animation.repeatCount = Float.infinity
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        animation.isRemovedOnCompletion = false
        return animation
    }

    func opacityAnimation(begin: CFTimeInterval) -> CAKeyframeAnimation {
        let animation = CAKeyframeAnimation(keyPath: "opacity")
        animation.values = [0.55, 1.0, 0.70, 0.95, 0.55]
        animation.keyTimes = numberValues([0, 0.28, 0.52, 0.76, 1])
        animation.duration = 5.4
        animation.beginTime = CACurrentMediaTime() + begin
        animation.repeatCount = Float.infinity
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        animation.isRemovedOnCompletion = false
        return animation
    }

    func glowColors(alphaScale: CGFloat) -> [CGColor] {
        [
            UIColor(red: 0.18, green: 0.68, blue: 1.00, alpha: 0.00).cgColor,
            UIColor(red: 0.20, green: 0.72, blue: 1.00, alpha: 0.78 * alphaScale).cgColor,
            UIColor(red: 0.76, green: 0.36, blue: 1.00, alpha: 0.62 * alphaScale).cgColor,
            UIColor(red: 1.00, green: 0.36, blue: 0.78, alpha: 0.58 * alphaScale).cgColor,
            UIColor(red: 0.24, green: 1.00, blue: 0.84, alpha: 0.66 * alphaScale).cgColor,
            UIColor(red: 1.00, green: 0.86, blue: 0.30, alpha: 0.40 * alphaScale).cgColor,
            UIColor(red: 0.18, green: 0.68, blue: 1.00, alpha: 0.00).cgColor
        ]
    }

    func highlightColors() -> [CGColor] {
        [
            UIColor.white.withAlphaComponent(0.00).cgColor,
            UIColor.white.withAlphaComponent(0.22).cgColor,
            UIColor(red: 0.82, green: 0.96, blue: 1.00, alpha: 0.10).cgColor,
            UIColor.white.withAlphaComponent(0.00).cgColor,
            UIColor.white.withAlphaComponent(0.08).cgColor,
            UIColor.white.withAlphaComponent(0.00).cgColor
        ]
    }

    func numberValues(_ values: [Double]) -> [NSNumber] {
        values.map { NSNumber(value: $0) }
    }
}
