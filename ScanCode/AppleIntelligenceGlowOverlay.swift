import QuartzCore
import UIKit

final class AppleIntelligenceGlowOverlayView: UIView {

    private let marqueeLayer = CAGradientLayer()
    private let softBloomLayer = CAGradientLayer()
    private let glassLayer = CAGradientLayer()
    private let marqueeMask = CAShapeLayer()
    private let softBloomMask = CAShapeLayer()
    private let glassMask = CAShapeLayer()
    private var baseBloomOpacity: Float = 0
    private var baseGlowOpacity: Float = 0
    private var baseGlassOpacity: Float = 0

    private var reduceMotion: Bool {
        UIAccessibility.isReduceMotionEnabled
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureView()
        configureGradientLayers()
        installReduceMotionObserver()
        updateMotionState()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureView()
        configureGradientLayers()
        installReduceMotionObserver()
        updateMotionState()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateLayerGeometry()
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        false
    }
}

private extension AppleIntelligenceGlowOverlayView {

    struct EdgeLightMetrics {
        let pathBounds: CGRect
        let cornerRadius: CGFloat
        let marqueeWidth: CGFloat
        let bloomWidth: CGFloat
        let glassWidth: CGFloat
        let glowOpacity: Float
        let bloomOpacity: Float
        let glassOpacity: Float
    }

    func configureView() {
        backgroundColor = .clear
        isOpaque = false
        isUserInteractionEnabled = false
        clipsToBounds = true
    }

    func configureGradientLayers() {
        configureConicLayer(softBloomLayer)
        configureConicLayer(marqueeLayer)
        configureConicLayer(glassLayer)

        softBloomLayer.colors = appleIntelligenceColors(alphaScale: 0.34)
        marqueeLayer.colors = appleIntelligenceColors(alphaScale: 0.62)
        glassLayer.colors = glassHighlightColors()

        softBloomLayer.locations = numberValues([0.00, 0.06, 0.13, 0.20, 0.31, 0.42, 0.52, 0.63, 0.76, 0.88, 1.00])
        marqueeLayer.locations = softBloomLayer.locations
        glassLayer.locations = numberValues([0.00, 0.045, 0.075, 0.12, 0.34, 0.58, 0.62, 0.68, 1.00])

        softBloomLayer.mask = softBloomMask
        marqueeLayer.mask = marqueeMask
        glassLayer.mask = glassMask

        layer.addSublayer(softBloomLayer)
        layer.addSublayer(marqueeLayer)
        layer.addSublayer(glassLayer)
    }

    func configureConicLayer(_ layer: CAGradientLayer) {
        layer.type = .conic
        layer.startPoint = CGPoint(x: 0.5, y: 0.5)
        layer.endPoint = CGPoint(x: 1, y: 0.5)
        layer.backgroundColor = UIColor.clear.cgColor
        layer.isOpaque = false
        layer.masksToBounds = false
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

    func updateLayerGeometry() {
        guard !bounds.isEmpty else { return }

        let metrics = edgeLightMetrics(for: bounds)
        let frame = bounds
        let path = UIBezierPath(roundedRect: metrics.pathBounds, cornerRadius: metrics.cornerRadius).cgPath

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        softBloomLayer.frame = frame
        marqueeLayer.frame = frame
        glassLayer.frame = frame

        updateMask(softBloomMask, path: path, lineWidth: metrics.bloomWidth)
        updateMask(marqueeMask, path: path, lineWidth: metrics.marqueeWidth)
        updateMask(glassMask, path: path, lineWidth: metrics.glassWidth)

        baseBloomOpacity = metrics.bloomOpacity
        baseGlowOpacity = metrics.glowOpacity
        baseGlassOpacity = metrics.glassOpacity

        CATransaction.commit()

        updateMotionState()
    }

    func updateMask(_ mask: CAShapeLayer, path: CGPath, lineWidth: CGFloat) {
        mask.path = path
        mask.fillColor = UIColor.clear.cgColor
        mask.strokeColor = UIColor.black.cgColor
        mask.lineWidth = lineWidth
        mask.lineJoin = .round
        mask.lineCap = .round
        mask.backgroundColor = UIColor.clear.cgColor
        mask.isOpaque = false
    }

    func updateMotionState() {
        removeAnimations()

        if reduceMotion {
            softBloomLayer.speed = 0
            marqueeLayer.speed = 0
            glassLayer.speed = 0
            softBloomLayer.opacity = baseBloomOpacity * 0.70
            marqueeLayer.opacity = baseGlowOpacity * 0.72
            glassLayer.opacity = baseGlassOpacity * 0.55
            return
        }

        softBloomLayer.speed = 1
        marqueeLayer.speed = 1
        glassLayer.speed = 1
        softBloomLayer.opacity = baseBloomOpacity
        marqueeLayer.opacity = baseGlowOpacity
        glassLayer.opacity = baseGlassOpacity

        addRotationAnimation(to: softBloomLayer, duration: 10.5, clockwise: true, key: "soft-bloom-rotation")
        addRotationAnimation(to: marqueeLayer, duration: 6.6, clockwise: true, key: "marquee-rotation")
        addRotationAnimation(to: glassLayer, duration: 4.8, clockwise: false, key: "glass-rotation")
        addBreathingAnimation(to: marqueeLayer)
    }

    func removeAnimations() {
        softBloomLayer.removeAllAnimations()
        marqueeLayer.removeAllAnimations()
        glassLayer.removeAllAnimations()
    }

    func addRotationAnimation(
        to layer: CALayer,
        duration: CFTimeInterval,
        clockwise: Bool,
        key: String
    ) {
        let animation = CABasicAnimation(keyPath: "transform.rotation.z")
        animation.fromValue = clockwise ? 0 : Double.pi * 2
        animation.toValue = clockwise ? Double.pi * 2 : 0
        animation.duration = duration
        animation.repeatCount = Float.infinity
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        animation.isRemovedOnCompletion = false

        layer.add(animation, forKey: key)
    }

    func addBreathingAnimation(to layer: CALayer) {
        let baseOpacity = layer.opacity
        let animation = CAKeyframeAnimation(keyPath: "opacity")
        animation.values = [
            NSNumber(value: baseOpacity * 0.82),
            NSNumber(value: min(baseOpacity * 1.12, 0.40)),
            NSNumber(value: baseOpacity * 0.92),
            NSNumber(value: min(baseOpacity * 1.06, 0.38)),
            NSNumber(value: baseOpacity * 0.82)
        ]
        animation.keyTimes = numberValues([0, 0.24, 0.50, 0.74, 1])
        animation.duration = 5.8
        animation.repeatCount = Float.infinity
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        animation.isRemovedOnCompletion = false

        layer.add(animation, forKey: "marquee-breathing")
    }

    func edgeLightMetrics(for bounds: CGRect) -> EdgeLightMetrics {
        if isIPhoneAirSized(bounds) {
            return EdgeLightMetrics(
                pathBounds: bounds.insetBy(dx: -22, dy: -22),
                cornerRadius: 72,
                marqueeWidth: 34,
                bloomWidth: 86,
                glassWidth: 2.4,
                glowOpacity: 0.30,
                bloomOpacity: 0.16,
                glassOpacity: 0.24
            )
        }

        let shortestSide = min(bounds.width, bounds.height)
        let scale = min(max(shortestSide / 420, 0.86), 1.18)
        let outset = 20 * scale

        return EdgeLightMetrics(
            pathBounds: bounds.insetBy(dx: -outset, dy: -outset),
            cornerRadius: max(62, shortestSide * 0.17),
            marqueeWidth: 32 * scale,
            bloomWidth: 80 * scale,
            glassWidth: 2.2 * scale,
            glowOpacity: 0.28,
            bloomOpacity: 0.15,
            glassOpacity: 0.22
        )
    }

    func isIPhoneAirSized(_ bounds: CGRect) -> Bool {
        let pointWidth = min(bounds.width, bounds.height)
        let pointHeight = max(bounds.width, bounds.height)
        let nativeSize = UIScreen.main.nativeBounds.size
        let nativeWidth = min(nativeSize.width, nativeSize.height)
        let nativeHeight = max(nativeSize.width, nativeSize.height)

        let matchesLogicalSize = abs(pointWidth - 420) <= 3 && abs(pointHeight - 912) <= 3
        let matchesNativeSize = abs(nativeWidth - 1260) <= 3 && abs(nativeHeight - 2736) <= 3

        return matchesLogicalSize || matchesNativeSize
    }

    func appleIntelligenceColors(alphaScale: CGFloat) -> [CGColor] {
        [
            UIColor(red: 0.18, green: 0.70, blue: 1.00, alpha: 0.00).cgColor,
            UIColor(red: 0.18, green: 0.70, blue: 1.00, alpha: 0.72 * alphaScale).cgColor,
            UIColor(red: 0.36, green: 0.52, blue: 1.00, alpha: 0.36 * alphaScale).cgColor,
            UIColor(red: 0.86, green: 0.34, blue: 1.00, alpha: 0.68 * alphaScale).cgColor,
            UIColor(red: 1.00, green: 0.35, blue: 0.72, alpha: 0.54 * alphaScale).cgColor,
            UIColor(red: 1.00, green: 0.76, blue: 0.26, alpha: 0.26 * alphaScale).cgColor,
            UIColor(red: 0.24, green: 1.00, blue: 0.82, alpha: 0.58 * alphaScale).cgColor,
            UIColor(red: 0.16, green: 0.76, blue: 1.00, alpha: 0.52 * alphaScale).cgColor,
            UIColor(red: 0.92, green: 0.42, blue: 1.00, alpha: 0.62 * alphaScale).cgColor,
            UIColor(red: 0.18, green: 0.70, blue: 1.00, alpha: 0.28 * alphaScale).cgColor,
            UIColor(red: 0.18, green: 0.70, blue: 1.00, alpha: 0.00).cgColor
        ]
    }

    func glassHighlightColors() -> [CGColor] {
        [
            UIColor.white.withAlphaComponent(0.00).cgColor,
            UIColor.white.withAlphaComponent(0.44).cgColor,
            UIColor(red: 0.78, green: 0.96, blue: 1.00, alpha: 0.26).cgColor,
            UIColor.white.withAlphaComponent(0.00).cgColor,
            UIColor.white.withAlphaComponent(0.00).cgColor,
            UIColor.white.withAlphaComponent(0.20).cgColor,
            UIColor.white.withAlphaComponent(0.34).cgColor,
            UIColor.white.withAlphaComponent(0.00).cgColor,
            UIColor.white.withAlphaComponent(0.00).cgColor
        ]
    }

    func numberValues(_ values: [Double]) -> [NSNumber] {
        values.map { NSNumber(value: $0) }
    }
}
