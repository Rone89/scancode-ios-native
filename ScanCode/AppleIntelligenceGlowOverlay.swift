import QuartzCore
import UIKit

final class AppleIntelligenceGlowOverlayView: UIView {

    private struct GlowSegment {
        let layer: CAShapeLayer
        let color: UIColor
        let lineWidth: CGFloat
        let dashLength: CGFloat
        let phaseOffset: CGFloat
        let duration: CFTimeInterval
        let opacity: Float
        let shadowOpacity: Float
        let shadowRadius: CGFloat
    }

    private var ambientSegments: [GlowSegment] = []
    private var glassSegments: [GlowSegment] = []

    private var reduceMotion: Bool {
        UIAccessibility.isReduceMotionEnabled
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureView()
        configureSegments()
        installReduceMotionObserver()
        updateMotionState()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureView()
        configureSegments()
        installReduceMotionObserver()
        updateMotionState()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateSegmentGeometry()
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

    func configureSegments() {
        ambientSegments = [
            ambientSegment(
                color: UIColor(red: 0.16, green: 0.70, blue: 1.00, alpha: 1),
                lineWidth: 76,
                dashLength: 360,
                phaseOffset: 0,
                duration: 11.5,
                opacity: 0.20
            ),
            ambientSegment(
                color: UIColor(red: 0.86, green: 0.34, blue: 1.00, alpha: 1),
                lineWidth: 68,
                dashLength: 310,
                phaseOffset: 420,
                duration: 13.0,
                opacity: 0.18
            ),
            ambientSegment(
                color: UIColor(red: 1.00, green: 0.35, blue: 0.72, alpha: 1),
                lineWidth: 72,
                dashLength: 330,
                phaseOffset: 840,
                duration: 12.2,
                opacity: 0.17
            ),
            ambientSegment(
                color: UIColor(red: 0.22, green: 1.00, blue: 0.82, alpha: 1),
                lineWidth: 64,
                dashLength: 280,
                phaseOffset: 1180,
                duration: 14.0,
                opacity: 0.16
            ),
            ambientSegment(
                color: UIColor(red: 1.00, green: 0.82, blue: 0.30, alpha: 1),
                lineWidth: 58,
                dashLength: 220,
                phaseOffset: 1520,
                duration: 15.5,
                opacity: 0.11
            )
        ]

        glassSegments = [
            glassSegment(dashLength: 150, phaseOffset: 160, duration: 8.0, opacity: 0.42),
            glassSegment(dashLength: 96, phaseOffset: 980, duration: 9.8, opacity: 0.30),
            glassSegment(dashLength: 120, phaseOffset: 1460, duration: 11.0, opacity: 0.24)
        ]

        (ambientSegments + glassSegments).forEach { segment in
            layer.addSublayer(segment.layer)
        }
    }

    private func ambientSegment(
        color: UIColor,
        lineWidth: CGFloat,
        dashLength: CGFloat,
        phaseOffset: CGFloat,
        duration: CFTimeInterval,
        opacity: Float
    ) -> GlowSegment {
        makeSegment(
            color: color,
            lineWidth: lineWidth,
            dashLength: dashLength,
            phaseOffset: phaseOffset,
            duration: duration,
            opacity: opacity,
            shadowOpacity: min(opacity + 0.12, 0.38),
            shadowRadius: lineWidth * 0.42
        )
    }

    private func glassSegment(
        dashLength: CGFloat,
        phaseOffset: CGFloat,
        duration: CFTimeInterval,
        opacity: Float
    ) -> GlowSegment {
        makeSegment(
            color: UIColor(red: 0.92, green: 0.98, blue: 1.00, alpha: 1),
            lineWidth: 3,
            dashLength: dashLength,
            phaseOffset: phaseOffset,
            duration: duration,
            opacity: opacity,
            shadowOpacity: 0.28,
            shadowRadius: 8
        )
    }

    private func makeSegment(
        color: UIColor,
        lineWidth: CGFloat,
        dashLength: CGFloat,
        phaseOffset: CGFloat,
        duration: CFTimeInterval,
        opacity: Float,
        shadowOpacity: Float,
        shadowRadius: CGFloat
    ) -> GlowSegment {
        let segmentLayer = CAShapeLayer()
        segmentLayer.fillColor = UIColor.clear.cgColor
        segmentLayer.strokeColor = color.cgColor
        segmentLayer.lineWidth = lineWidth
        segmentLayer.lineJoin = .round
        segmentLayer.lineCap = .round
        segmentLayer.opacity = opacity
        segmentLayer.shadowColor = color.cgColor
        segmentLayer.shadowOpacity = shadowOpacity
        segmentLayer.shadowRadius = shadowRadius
        segmentLayer.shadowOffset = .zero
        segmentLayer.backgroundColor = UIColor.clear.cgColor
        segmentLayer.isOpaque = false

        return GlowSegment(
            layer: segmentLayer,
            color: color,
            lineWidth: lineWidth,
            dashLength: dashLength,
            phaseOffset: phaseOffset,
            duration: duration,
            opacity: opacity,
            shadowOpacity: shadowOpacity,
            shadowRadius: shadowRadius
        )
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

    func updateSegmentGeometry() {
        guard !bounds.isEmpty else { return }

        let shortestSide = min(bounds.width, bounds.height)
        let cornerRadius = max(34, shortestSide * 0.10)
        let pathBounds = bounds.insetBy(dx: 1, dy: 1)
        let path = UIBezierPath(roundedRect: pathBounds, cornerRadius: cornerRadius).cgPath
        let perimeter = roundedRectPerimeter(width: pathBounds.width, height: pathBounds.height, radius: cornerRadius)

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        (ambientSegments + glassSegments).forEach { segment in
            segment.layer.frame = bounds
            segment.layer.path = path
            segment.layer.lineWidth = adjustedLineWidth(segment.lineWidth, shortestSide: shortestSide)
            segment.layer.lineDashPattern = dashPattern(
                dashLength: adjustedDashLength(segment.dashLength, shortestSide: shortestSide),
                perimeter: perimeter
            )
            segment.layer.lineDashPhase = segment.phaseOffset.truncatingRemainder(dividingBy: perimeter)
            segment.layer.shadowRadius = adjustedShadowRadius(segment.shadowRadius, shortestSide: shortestSide)
        }

        CATransaction.commit()

        updateMotionState()
    }

    func updateMotionState() {
        removeAnimations()

        if reduceMotion {
            ambientSegments.forEach { segment in
                segment.layer.opacity = min(segment.opacity, 0.10)
                segment.layer.shadowOpacity = min(segment.shadowOpacity, 0.12)
            }
            glassSegments.forEach { segment in
                segment.layer.opacity = min(segment.opacity, 0.16)
                segment.layer.shadowOpacity = 0.10
            }
        } else {
            ambientSegments.forEach { segment in
                segment.layer.opacity = segment.opacity
                segment.layer.shadowOpacity = segment.shadowOpacity
                addPhaseAnimation(to: segment, reversed: false)
                addBreathingAnimation(to: segment.layer, baseOpacity: segment.opacity)
            }
            glassSegments.forEach { segment in
                segment.layer.opacity = segment.opacity
                segment.layer.shadowOpacity = segment.shadowOpacity
                addPhaseAnimation(to: segment, reversed: true)
            }
        }
    }

    func removeAnimations() {
        (ambientSegments + glassSegments).forEach { segment in
            segment.layer.removeAllAnimations()
        }
    }

    private func addPhaseAnimation(to segment: GlowSegment, reversed: Bool) {
        guard let pattern = segment.layer.lineDashPattern, pattern.count >= 2 else { return }

        let dashLength = CGFloat(pattern[0].doubleValue)
        let gapLength = CGFloat(pattern[1].doubleValue)
        let perimeter = dashLength + gapLength
        let basePhase = segment.layer.lineDashPhase
        let direction: CGFloat = reversed ? 1 : -1

        let animation = CABasicAnimation(keyPath: "lineDashPhase")
        animation.fromValue = NSNumber(value: Double(basePhase))
        animation.toValue = NSNumber(value: Double(basePhase + direction * perimeter))
        animation.duration = segment.duration
        animation.repeatCount = Float.infinity
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        animation.isRemovedOnCompletion = false

        segment.layer.add(animation, forKey: "edge-light-phase")
    }

    func addBreathingAnimation(to layer: CALayer, baseOpacity: Float) {
        let animation = CAKeyframeAnimation(keyPath: "opacity")
        animation.values = [
            NSNumber(value: baseOpacity * 0.70),
            NSNumber(value: min(baseOpacity * 1.18, 0.32)),
            NSNumber(value: baseOpacity * 0.86),
            NSNumber(value: min(baseOpacity * 1.08, 0.30)),
            NSNumber(value: baseOpacity * 0.70)
        ]
        animation.keyTimes = numberValues([0, 0.26, 0.52, 0.78, 1])
        animation.duration = 6.8
        animation.repeatCount = Float.infinity
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        animation.isRemovedOnCompletion = false

        layer.add(animation, forKey: "edge-light-breathing")
    }

    func adjustedLineWidth(_ value: CGFloat, shortestSide: CGFloat) -> CGFloat {
        let scale = shortestSide / 393
        return max(value * min(max(scale, 0.86), 1.35), value * 0.72)
    }

    func adjustedDashLength(_ value: CGFloat, shortestSide: CGFloat) -> CGFloat {
        let scale = shortestSide / 393
        return max(value * min(max(scale, 0.82), 1.28), value * 0.70)
    }

    func adjustedShadowRadius(_ value: CGFloat, shortestSide: CGFloat) -> CGFloat {
        let scale = shortestSide / 393
        return max(value * min(max(scale, 0.84), 1.30), value * 0.70)
    }

    func dashPattern(dashLength: CGFloat, perimeter: CGFloat) -> [NSNumber] {
        let clampedDashLength = min(max(dashLength, 90), perimeter * 0.28)
        let gapLength = max(perimeter - clampedDashLength, 1)

        return [
            NSNumber(value: Double(clampedDashLength)),
            NSNumber(value: Double(gapLength))
        ]
    }

    func roundedRectPerimeter(width: CGFloat, height: CGFloat, radius: CGFloat) -> CGFloat {
        let clampedRadius = min(radius, min(width, height) / 2)
        return 2 * (width + height - 4 * clampedRadius) + 2 * CGFloat.pi * clampedRadius
    }

    func numberValues(_ values: [Double]) -> [NSNumber] {
        values.map { NSNumber(value: $0) }
    }
}
