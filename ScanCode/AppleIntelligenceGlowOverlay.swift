import QuartzCore
import UIKit

final class AppleIntelligenceGlowOverlayView: UIView {

    private struct GlowSegment {
        let layer: CAShapeLayer
        let placement: SegmentPlacement
        let lineWidth: CGFloat
        let dashFraction: CGFloat
        let phaseFraction: CGFloat
        let duration: CFTimeInterval
        let opacity: Float
        let shadowOpacity: Float
        let shadowRadius: CGFloat
    }

    private enum SegmentPlacement {
        case ambient
        case glass
    }

    private struct EdgeLightProfile {
        let ambientOutset: CGFloat
        let ambientCornerRadius: CGFloat
        let ambientWidthScale: CGFloat
        let ambientDashScale: CGFloat
        let ambientShadowScale: CGFloat
        let glassInset: CGFloat
        let glassCornerRadius: CGFloat
        let glassWidthScale: CGFloat
        let glassDashScale: CGFloat
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
                lineWidth: 108,
                dashFraction: 0.19,
                phaseFraction: 0.02,
                duration: 13.5,
                opacity: 0.18
            ),
            ambientSegment(
                color: UIColor(red: 0.86, green: 0.34, blue: 1.00, alpha: 1),
                lineWidth: 98,
                dashFraction: 0.16,
                phaseFraction: 0.24,
                duration: 15.0,
                opacity: 0.16
            ),
            ambientSegment(
                color: UIColor(red: 1.00, green: 0.35, blue: 0.72, alpha: 1),
                lineWidth: 102,
                dashFraction: 0.17,
                phaseFraction: 0.46,
                duration: 14.2,
                opacity: 0.15
            ),
            ambientSegment(
                color: UIColor(red: 0.22, green: 1.00, blue: 0.82, alpha: 1),
                lineWidth: 92,
                dashFraction: 0.14,
                phaseFraction: 0.66,
                duration: 16.0,
                opacity: 0.14
            ),
            ambientSegment(
                color: UIColor(red: 1.00, green: 0.82, blue: 0.30, alpha: 1),
                lineWidth: 84,
                dashFraction: 0.11,
                phaseFraction: 0.84,
                duration: 17.5,
                opacity: 0.10
            )
        ]

        glassSegments = [
            glassSegment(dashFraction: 0.070, phaseFraction: 0.08, duration: 9.0, opacity: 0.34),
            glassSegment(dashFraction: 0.046, phaseFraction: 0.52, duration: 11.0, opacity: 0.24),
            glassSegment(dashFraction: 0.058, phaseFraction: 0.76, duration: 12.5, opacity: 0.20)
        ]

        (ambientSegments + glassSegments).forEach { segment in
            layer.addSublayer(segment.layer)
        }
    }

    private func ambientSegment(
        color: UIColor,
        lineWidth: CGFloat,
        dashFraction: CGFloat,
        phaseFraction: CGFloat,
        duration: CFTimeInterval,
        opacity: Float
    ) -> GlowSegment {
        makeSegment(
            color: color,
            placement: .ambient,
            lineWidth: lineWidth,
            dashFraction: dashFraction,
            phaseFraction: phaseFraction,
            duration: duration,
            opacity: opacity,
            shadowOpacity: min(opacity + 0.12, 0.38),
            shadowRadius: lineWidth * 0.42
        )
    }

    private func glassSegment(
        dashFraction: CGFloat,
        phaseFraction: CGFloat,
        duration: CFTimeInterval,
        opacity: Float
    ) -> GlowSegment {
        makeSegment(
            color: UIColor(red: 0.92, green: 0.98, blue: 1.00, alpha: 1),
            placement: .glass,
            lineWidth: 2.4,
            dashFraction: dashFraction,
            phaseFraction: phaseFraction,
            duration: duration,
            opacity: opacity,
            shadowOpacity: 0.28,
            shadowRadius: 8
        )
    }

    private func makeSegment(
        color: UIColor,
        placement: SegmentPlacement,
        lineWidth: CGFloat,
        dashFraction: CGFloat,
        phaseFraction: CGFloat,
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
            placement: placement,
            lineWidth: lineWidth,
            dashFraction: dashFraction,
            phaseFraction: phaseFraction,
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

        let profile = edgeLightProfile(for: bounds)

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        (ambientSegments + glassSegments).forEach { segment in
            let metrics = segmentMetrics(for: segment, profile: profile)
            let path = UIBezierPath(roundedRect: metrics.pathBounds, cornerRadius: metrics.cornerRadius).cgPath
            let perimeter = roundedRectPerimeter(
                width: metrics.pathBounds.width,
                height: metrics.pathBounds.height,
                radius: metrics.cornerRadius
            )

            segment.layer.frame = bounds
            segment.layer.path = path
            segment.layer.lineWidth = metrics.lineWidth
            segment.layer.lineDashPattern = dashPattern(
                dashLength: perimeter * segment.dashFraction * metrics.dashScale,
                perimeter: perimeter
            )
            segment.layer.lineDashPhase = (perimeter * segment.phaseFraction).truncatingRemainder(dividingBy: perimeter)
            segment.layer.shadowRadius = segment.shadowRadius * metrics.shadowScale
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

    func dashPattern(dashLength: CGFloat, perimeter: CGFloat) -> [NSNumber] {
        let clampedDashLength = min(max(dashLength, 96), perimeter * 0.24)
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

    private func edgeLightProfile(for bounds: CGRect) -> EdgeLightProfile {
        if isIPhoneAirSized(bounds) {
            return EdgeLightProfile(
                ambientOutset: 34,
                ambientCornerRadius: 88,
                ambientWidthScale: 1.0,
                ambientDashScale: 1.0,
                ambientShadowScale: 1.0,
                glassInset: 5,
                glassCornerRadius: 58,
                glassWidthScale: 1.0,
                glassDashScale: 1.0
            )
        }

        let shortestSide = min(bounds.width, bounds.height)
        let scale = min(max(shortestSide / 420, 0.86), 1.18)

        return EdgeLightProfile(
            ambientOutset: 30 * scale,
            ambientCornerRadius: max(72, shortestSide * 0.20),
            ambientWidthScale: scale,
            ambientDashScale: scale,
            ambientShadowScale: scale,
            glassInset: 5,
            glassCornerRadius: max(48, shortestSide * 0.138),
            glassWidthScale: scale,
            glassDashScale: scale
        )
    }

    private func isIPhoneAirSized(_ bounds: CGRect) -> Bool {
        let pointWidth = min(bounds.width, bounds.height)
        let pointHeight = max(bounds.width, bounds.height)
        let nativeSize = UIScreen.main.nativeBounds.size
        let nativeWidth = min(nativeSize.width, nativeSize.height)
        let nativeHeight = max(nativeSize.width, nativeSize.height)

        let matchesLogicalSize = abs(pointWidth - 420) <= 3 && abs(pointHeight - 912) <= 3
        let matchesNativeSize = abs(nativeWidth - 1260) <= 3 && abs(nativeHeight - 2736) <= 3

        return matchesLogicalSize || matchesNativeSize
    }

    private func segmentMetrics(
        for segment: GlowSegment,
        profile: EdgeLightProfile
    ) -> (
        pathBounds: CGRect,
        cornerRadius: CGFloat,
        lineWidth: CGFloat,
        dashScale: CGFloat,
        shadowScale: CGFloat
    ) {
        switch segment.placement {
        case .ambient:
            return (
                pathBounds: bounds.insetBy(dx: -profile.ambientOutset, dy: -profile.ambientOutset),
                cornerRadius: profile.ambientCornerRadius,
                lineWidth: segment.lineWidth * profile.ambientWidthScale,
                dashScale: profile.ambientDashScale,
                shadowScale: profile.ambientShadowScale
            )

        case .glass:
            return (
                pathBounds: bounds.insetBy(dx: profile.glassInset, dy: profile.glassInset),
                cornerRadius: profile.glassCornerRadius,
                lineWidth: segment.lineWidth * profile.glassWidthScale,
                dashScale: profile.glassDashScale,
                shadowScale: profile.glassWidthScale
            )
        }
    }
}
