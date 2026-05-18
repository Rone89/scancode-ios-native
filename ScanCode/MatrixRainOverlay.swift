import QuartzCore
import UIKit

final class MatrixRainOverlayView: UIView {

    private let backgroundRainLayer = CAEmitterLayer()
    private let foregroundRainLayer = CAEmitterLayer()
    private let topFadeLayer = CAGradientLayer()
    private let symbols = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ#$%&*+-=<>")

    private var reduceMotion: Bool {
        UIAccessibility.isReduceMotionEnabled
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureView()
        configureFadeLayer()
        configureEmitterLayers()
        installReduceMotionObserver()
        updateMotionState()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureView()
        configureFadeLayer()
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
        clipsToBounds = true
        accessibilityElementsHidden = true
    }

    func configureFadeLayer() {
        topFadeLayer.colors = [
            UIColor.black.withAlphaComponent(0.22).cgColor,
            UIColor.clear.cgColor,
            UIColor.black.withAlphaComponent(0.12).cgColor
        ]
        topFadeLayer.locations = numberValues([0, 0.18, 1])
        topFadeLayer.startPoint = CGPoint(x: 0.5, y: 0)
        topFadeLayer.endPoint = CGPoint(x: 0.5, y: 1)
        topFadeLayer.isOpaque = false
        layer.addSublayer(topFadeLayer)
    }

    func configureEmitterLayers() {
        configureEmitterLayer(backgroundRainLayer)
        configureEmitterLayer(foregroundRainLayer)

        backgroundRainLayer.emitterCells = makeBackgroundCells()
        foregroundRainLayer.emitterCells = makeForegroundCells()

        layer.addSublayer(backgroundRainLayer)
        layer.addSublayer(foregroundRainLayer)
    }

    func configureEmitterLayer(_ emitterLayer: CAEmitterLayer) {
        emitterLayer.emitterShape = .line
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

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        topFadeLayer.frame = currentBounds

        [backgroundRainLayer, foregroundRainLayer].forEach { emitterLayer in
            emitterLayer.frame = currentBounds
            emitterLayer.emitterPosition = CGPoint(x: currentBounds.midX, y: -18)
            emitterLayer.emitterSize = CGSize(width: currentBounds.width, height: 1)
        }

        CATransaction.commit()
    }

    func updateMotionState() {
        if reduceMotion {
            backgroundRainLayer.birthRate = 0.16
            foregroundRainLayer.birthRate = 0.04
            backgroundRainLayer.speed = 0.22
            foregroundRainLayer.speed = 0.16
            topFadeLayer.opacity = 0.65
        } else {
            backgroundRainLayer.birthRate = 1
            foregroundRainLayer.birthRate = 1
            backgroundRainLayer.speed = 1
            foregroundRainLayer.speed = 1
            topFadeLayer.opacity = 1
        }
    }

    func makeBackgroundCells() -> [CAEmitterCell] {
        symbols.enumerated().compactMap { index, symbol in
            guard index % 2 == 0 else { return nil }

            let cell = matrixCell(
                symbol: symbol,
                fontSize: 15,
                color: UIColor(red: 0.20, green: 1.00, blue: 0.38, alpha: 0.22),
                birthRate: 2.8,
                lifetime: 7.8,
                velocity: 118,
                velocityRange: 44,
                scale: 0.82,
                scaleRange: 0.22,
                alphaSpeed: -0.030
            )
            cell.beginTime = CFTimeInterval(index) * 0.018
            return cell
        }
    }

    func makeForegroundCells() -> [CAEmitterCell] {
        symbols.enumerated().compactMap { index, symbol in
            guard index % 5 == 0 else { return nil }

            let cell = matrixCell(
                symbol: symbol,
                fontSize: 18,
                color: UIColor(red: 0.72, green: 1.00, blue: 0.76, alpha: 0.44),
                birthRate: 0.72,
                lifetime: 5.2,
                velocity: 168,
                velocityRange: 36,
                scale: 0.90,
                scaleRange: 0.16,
                alphaSpeed: -0.070
            )
            cell.beginTime = CFTimeInterval(index) * 0.025
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
        alphaSpeed: Float
    ) -> CAEmitterCell {
        let cell = CAEmitterCell()
        cell.contents = glyphImage(for: String(symbol), fontSize: fontSize, color: color).cgImage
        cell.birthRate = birthRate
        cell.lifetime = lifetime
        cell.lifetimeRange = lifetime * 0.32
        cell.velocity = velocity
        cell.velocityRange = velocityRange
        cell.emissionLongitude = .pi / 2
        cell.emissionRange = 0.015
        cell.yAcceleration = 10
        cell.xAcceleration = 0
        cell.spin = 0
        cell.spinRange = 0
        cell.scale = scale
        cell.scaleRange = scaleRange
        cell.alphaSpeed = alphaSpeed
        cell.alphaRange = 0.08
        return cell
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
}
