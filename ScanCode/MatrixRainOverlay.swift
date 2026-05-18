import QuartzCore
import UIKit

final class MatrixRainOverlayView: UIView {

    private enum Edge {
        case top
        case right
        case bottom
        case left
    }

    private let topLayer = CAEmitterLayer()
    private let rightLayer = CAEmitterLayer()
    private let bottomLayer = CAEmitterLayer()
    private let leftLayer = CAEmitterLayer()
    private let topLeftCornerLayer = CAEmitterLayer()
    private let topRightCornerLayer = CAEmitterLayer()
    private let bottomLeftCornerLayer = CAEmitterLayer()
    private let bottomRightCornerLayer = CAEmitterLayer()
    private let edgeMaskLayer = CAShapeLayer()
    private let vignetteLayer = CAGradientLayer()
    private let symbols = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ#$%&*+-=<>")

    private var emitterLayers: [CAEmitterLayer] {
        [
            topLayer,
            rightLayer,
            bottomLayer,
            leftLayer,
            topLeftCornerLayer,
            topRightCornerLayer,
            bottomLeftCornerLayer,
            bottomRightCornerLayer
        ]
    }

    private var reduceMotion: Bool {
        UIAccessibility.isReduceMotionEnabled
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureView()
        configureVignetteLayer()
        configureEmitterLayers()
        installReduceMotionObserver()
        updateMotionState()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureView()
        configureVignetteLayer()
        configureEmitterLayers()
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

private extension MatrixRainOverlayView {

    func configureView() {
        backgroundColor = .clear
        isOpaque = false
        isUserInteractionEnabled = false
        accessibilityElementsHidden = true
        clipsToBounds = true
        layer.mask = edgeMaskLayer
    }

    func configureVignetteLayer() {
        vignetteLayer.colors = [
            UIColor.black.withAlphaComponent(0.20).cgColor,
            UIColor.clear.cgColor,
            UIColor.clear.cgColor,
            UIColor.black.withAlphaComponent(0.12).cgColor
        ]
        vignetteLayer.locations = numberValues([0, 0.12, 0.84, 1])
        vignetteLayer.startPoint = CGPoint(x: 0.5, y: 0)
        vignetteLayer.endPoint = CGPoint(x: 0.5, y: 1)
        vignetteLayer.isOpaque = false
        layer.addSublayer(vignetteLayer)
    }

    func configureEmitterLayers() {
        configureEmitterLayer(topLayer)
        configureEmitterLayer(rightLayer)
        configureEmitterLayer(bottomLayer)
        configureEmitterLayer(leftLayer)
        configureEmitterLayer(topLeftCornerLayer)
        configureEmitterLayer(topRightCornerLayer)
        configureEmitterLayer(bottomLeftCornerLayer)
        configureEmitterLayer(bottomRightCornerLayer)

        topLayer.emitterCells = makeEdgeCells(edge: .top, major: true)
        rightLayer.emitterCells = makeEdgeCells(edge: .right, major: false)
        bottomLayer.emitterCells = makeEdgeCells(edge: .bottom, major: true)
        leftLayer.emitterCells = makeEdgeCells(edge: .left, major: false)
        topLeftCornerLayer.emitterCells = makeCornerCells(phase: 0)
        topRightCornerLayer.emitterCells = makeCornerCells(phase: 1)
        bottomLeftCornerLayer.emitterCells = makeCornerCells(phase: 2)
        bottomRightCornerLayer.emitterCells = makeCornerCells(phase: 3)

        emitterLayers.forEach { layer.addSublayer($0) }
    }

    func configureEmitterLayer(_ emitterLayer: CAEmitterLayer) {
        emitterLayer.emitterMode = .surface
        emitterLayer.renderMode = .oldestLast
        emitterLayer.preservesDepth = false
        emitterLayer.masksToBounds = false
        emitterLayer.backgroundColor = UIColor.clear.cgColor
        emitterLayer.isOpaque = false
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

        let bandWidth = edgeBandWidth(for: currentBounds)
        let cornerDiameter = max(bandWidth * 2.2, 92)

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        vignetteLayer.frame = currentBounds
        edgeMaskLayer.frame = currentBounds
        edgeMaskLayer.path = edgeMaskPath(bounds: currentBounds, bandWidth: bandWidth).cgPath
        edgeMaskLayer.fillRule = .evenOdd

        topLayer.frame = currentBounds
        topLayer.emitterShape = .rectangle
        topLayer.emitterPosition = CGPoint(x: currentBounds.midX, y: bandWidth / 2)
        topLayer.emitterSize = CGSize(width: currentBounds.width, height: bandWidth)

        bottomLayer.frame = currentBounds
        bottomLayer.emitterShape = .rectangle
        bottomLayer.emitterPosition = CGPoint(x: currentBounds.midX, y: currentBounds.maxY - bandWidth / 2)
        bottomLayer.emitterSize = CGSize(width: currentBounds.width, height: bandWidth)

        leftLayer.frame = currentBounds
        leftLayer.emitterShape = .rectangle
        leftLayer.emitterPosition = CGPoint(x: bandWidth / 2, y: currentBounds.midY)
        leftLayer.emitterSize = CGSize(width: bandWidth, height: currentBounds.height)

        rightLayer.frame = currentBounds
        rightLayer.emitterShape = .rectangle
        rightLayer.emitterPosition = CGPoint(x: currentBounds.maxX - bandWidth / 2, y: currentBounds.midY)
        rightLayer.emitterSize = CGSize(width: bandWidth, height: currentBounds.height)

        updateCornerLayer(topLeftCornerLayer, position: CGPoint(x: bandWidth / 2, y: bandWidth / 2), size: cornerDiameter)
        updateCornerLayer(
            topRightCornerLayer,
            position: CGPoint(x: currentBounds.maxX - bandWidth / 2, y: bandWidth / 2),
            size: cornerDiameter
        )
        updateCornerLayer(
            bottomLeftCornerLayer,
            position: CGPoint(x: bandWidth / 2, y: currentBounds.maxY - bandWidth / 2),
            size: cornerDiameter
        )
        updateCornerLayer(
            bottomRightCornerLayer,
            position: CGPoint(x: currentBounds.maxX - bandWidth / 2, y: currentBounds.maxY - bandWidth / 2),
            size: cornerDiameter
        )

        CATransaction.commit()
    }

    func updateMotionState() {
        if reduceMotion {
            topLayer.birthRate = 0.18
            rightLayer.birthRate = 0.14
            bottomLayer.birthRate = 0.18
            leftLayer.birthRate = 0.14
            topLeftCornerLayer.birthRate = 0.06
            topRightCornerLayer.birthRate = 0.06
            bottomLeftCornerLayer.birthRate = 0.06
            bottomRightCornerLayer.birthRate = 0.06
            emitterLayers.forEach { $0.speed = 0.18 }
            vignetteLayer.opacity = 0.58
        } else {
            topLayer.birthRate = 1.0
            rightLayer.birthRate = 0.82
            bottomLayer.birthRate = 0.92
            leftLayer.birthRate = 0.82
            topLeftCornerLayer.birthRate = 0.36
            topRightCornerLayer.birthRate = 0.36
            bottomLeftCornerLayer.birthRate = 0.36
            bottomRightCornerLayer.birthRate = 0.36
            emitterLayers.forEach { $0.speed = 1 }
            vignetteLayer.opacity = 1
        }
    }

    func makeEdgeCells(edge: Edge, major: Bool) -> [CAEmitterCell] {
        symbols.enumerated().compactMap { index, symbol in
            guard major ? index % 2 == 0 : index % 3 == 0 else { return nil }

            let bright = index % 11 == 0
            let cell = matrixCell(
                symbol: symbol,
                fontSize: bright ? 18 : 15,
                color: bright
                    ? UIColor(red: 0.76, green: 1.00, blue: 0.78, alpha: 0.42)
                    : UIColor(red: 0.20, green: 1.00, blue: 0.38, alpha: major ? 0.22 : 0.18),
                birthRate: bright ? 0.48 : (major ? 1.9 : 1.35),
                lifetime: major ? 4.8 : 4.3,
                velocity: bright ? 52 : 38,
                velocityRange: 26,
                scale: bright ? 0.90 : 0.82,
                scaleRange: 0.18,
                alphaSpeed: bright ? -0.10 : -0.060,
                emissionLongitude: emissionLongitude(for: edge)
            )
            cell.beginTime = CFTimeInterval(index) * 0.022
            return cell
        }
    }

    func updateCornerLayer(_ emitterLayer: CAEmitterLayer, position: CGPoint, size: CGFloat) {
        emitterLayer.frame = bounds
        emitterLayer.emitterShape = .rectangle
        emitterLayer.emitterPosition = position
        emitterLayer.emitterSize = CGSize(width: size, height: size)
    }

    func makeCornerCells(phase: Int) -> [CAEmitterCell] {
        symbols.enumerated().compactMap { index, symbol in
            guard index % 4 == 0 else { return nil }

            let cell = matrixCell(
                symbol: symbol,
                fontSize: 14,
                color: UIColor(red: 0.28, green: 1.00, blue: 0.42, alpha: 0.16),
                birthRate: 0.58,
                lifetime: 3.8,
                velocity: 34,
                velocityRange: 30,
                scale: 0.78,
                scaleRange: 0.22,
                alphaSpeed: -0.075,
                emissionLongitude: CGFloat((index + phase * 2) % 8) * .pi / 4
            )
            cell.emissionRange = .pi * 2
            cell.beginTime = CFTimeInterval(index + phase) * 0.030
            return cell
        }
    }

    func matrixCell(
        symbol: Character,
        fontSize: CGFloat,
        color: UIColor,
        birthRate: Float,
        lifetime: Float,
        velocity: CGFloat,
        velocityRange: CGFloat,
        scale: CGFloat,
        scaleRange: CGFloat,
        alphaSpeed: Float,
        emissionLongitude: CGFloat
    ) -> CAEmitterCell {
        let cell = CAEmitterCell()
        cell.contents = glyphImage(for: String(symbol), fontSize: fontSize, color: color).cgImage
        cell.birthRate = birthRate
        cell.lifetime = lifetime
        cell.lifetimeRange = lifetime * 0.30
        cell.velocity = velocity
        cell.velocityRange = velocityRange
        cell.emissionLongitude = emissionLongitude
        cell.emissionRange = 0.34
        cell.yAcceleration = 0
        cell.xAcceleration = 0
        cell.spin = 0
        cell.spinRange = 0
        cell.scale = scale
        cell.scaleRange = scaleRange
        cell.alphaSpeed = alphaSpeed
        cell.alphaRange = 0.08
        return cell
    }

    func emissionLongitude(for edge: Edge) -> CGFloat {
        switch edge {
        case .top:
            return .pi / 2
        case .right:
            return .pi
        case .bottom:
            return -.pi / 2
        case .left:
            return 0
        }
    }

    func edgeBandWidth(for bounds: CGRect) -> CGFloat {
        min(max(min(bounds.width, bounds.height) * 0.13, 44), 68)
    }

    func edgeMaskPath(bounds: CGRect, bandWidth: CGFloat) -> UIBezierPath {
        let outerPath = UIBezierPath(rect: bounds)
        let innerRect = bounds.insetBy(dx: bandWidth, dy: bandWidth)
        let innerCornerRadius = max(24, min(bounds.width, bounds.height) * 0.08)
        let innerPath = UIBezierPath(roundedRect: innerRect, cornerRadius: innerCornerRadius)

        outerPath.append(innerPath)
        return outerPath
    }

    func glyphImage(for text: String, fontSize: CGFloat, color: UIColor) -> UIImage {
        let font = UIFont.monospacedSystemFont(ofSize: fontSize, weight: .semibold)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]
        let measuredSize = text.size(withAttributes: attributes)
        let imageSize = CGSize(
            width: ceil(measuredSize.width + 4),
            height: ceil(measuredSize.height + 4)
        )
        let renderer = UIGraphicsImageRenderer(size: imageSize)

        return renderer.image { context in
            UIColor.clear.setFill()
            context.fill(CGRect(origin: .zero, size: imageSize))
            text.draw(
                at: CGPoint(x: 2, y: 2),
                withAttributes: attributes
            )
        }
    }

    func numberValues(_ values: [Double]) -> [NSNumber] {
        values.map { NSNumber(value: $0) }
    }
}
