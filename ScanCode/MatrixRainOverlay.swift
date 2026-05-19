import QuartzCore
import UIKit

final class MatrixRainOverlayView: UIView {

    private let renderer = MatrixRainRenderer()
    private var displayLink: CADisplayLink?
    private var lastFrameTimestamp: CFTimeInterval?
    private var reduceMotion = UIAccessibility.isReduceMotionEnabled

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureView()
        installObservers()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureView()
        installObservers()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        stopDisplayLink()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()

        if window == nil {
            stopDisplayLink()
        } else {
            renderer.updateLayout(for: bounds, reduceMotion: reduceMotion)
            startDisplayLink()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        renderer.updateLayout(for: bounds, reduceMotion: reduceMotion)
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext(), !bounds.isEmpty else { return }
        renderer.draw(in: context, bounds: bounds, reduceMotion: reduceMotion)
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
        clearsContextBeforeDrawing = true
        contentMode = .redraw
    }

    func installObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleReduceMotionStatusChanged),
            name: UIAccessibility.reduceMotionStatusDidChangeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleApplicationDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleApplicationWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
    }

    func startDisplayLink() {
        guard displayLink == nil else {
            displayLink?.isPaused = false
            return
        }

        let link = CADisplayLink(target: self, selector: #selector(handleDisplayLink(_:)))
        link.preferredFramesPerSecond = reduceMotion ? 10 : 24
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
        lastFrameTimestamp = nil
    }

    @objc func handleDisplayLink(_ link: CADisplayLink) {
        defer {
            lastFrameTimestamp = link.timestamp
        }

        guard !bounds.isEmpty else { return }

        let deltaTime: TimeInterval
        if let lastFrameTimestamp {
            deltaTime = min(max(link.timestamp - lastFrameTimestamp, 0), 1.0 / 12.0)
        } else {
            deltaTime = 1.0 / Double(max(link.preferredFramesPerSecond, 1))
        }

        renderer.advance(by: CGFloat(deltaTime), reduceMotion: reduceMotion)
        setNeedsDisplay()
    }

    @objc func handleReduceMotionStatusChanged() {
        reduceMotion = UIAccessibility.isReduceMotionEnabled
        displayLink?.preferredFramesPerSecond = reduceMotion ? 10 : 24
        renderer.updateLayout(for: bounds, reduceMotion: reduceMotion)
        setNeedsDisplay()
    }

    @objc func handleApplicationDidBecomeActive() {
        displayLink?.isPaused = false
    }

    @objc func handleApplicationWillResignActive() {
        displayLink?.isPaused = true
    }
}

private final class MatrixRainRenderer {

    private enum Edge: Equatable {
        case top
        case right
        case bottom
        case left
    }

    private enum Corner: Equatable {
        case topLeft
        case topRight
        case bottomLeft
        case bottomRight
    }

    private enum StreamKind {
        case edge(Edge)
        case corner(Corner)

        func matches(_ edge: Edge) -> Bool {
            if case let .edge(candidate) = self {
                return candidate == edge
            }
            return false
        }

        func matches(_ corner: Corner) -> Bool {
            if case let .corner(candidate) = self {
                return candidate == corner
            }
            return false
        }
    }

    private struct RainStream {
        let kind: StreamKind
        let crossOffset: CGFloat
        let depthOffset: CGFloat
        let glyphSize: CGFloat
        let glyphSpacing: CGFloat
        let glyphCount: Int
        let speed: CGFloat
        let resetOffset: CGFloat
        let wobble: CGFloat
        let phase: CGFloat
        var head: CGFloat
        var glyphs: [String]
        var shuffleCountdown: CGFloat
    }

    private let symbols = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ#$%&*+-=<>")
    private var streams: [RainStream] = []
    private var layoutSignature = ""
    private var bandWidth: CGFloat = 58
    private var cornerSize: CGFloat = 92
    private var baseFont: UIFont = .monospacedSystemFont(ofSize: 14, weight: .semibold)
    private var headFont: UIFont = .monospacedSystemFont(ofSize: 15, weight: .heavy)

    func updateLayout(for bounds: CGRect, reduceMotion: Bool) {
        guard !bounds.isEmpty else {
            streams.removeAll()
            layoutSignature = ""
            return
        }

        let newBandWidth = edgeBandWidth(for: bounds)
        let newCornerSize = min(max(newBandWidth * 1.55, 88), 124)
        let newGlyphSize = glyphSize(for: bounds)
        let signature = [
            Int(bounds.width.rounded()),
            Int(bounds.height.rounded()),
            Int(newBandWidth.rounded()),
            Int(newCornerSize.rounded()),
            Int(newGlyphSize.rounded()),
            reduceMotion ? 1 : 0
        ]
        .map(String.init)
        .joined(separator: "-")

        guard signature != layoutSignature else { return }

        bandWidth = newBandWidth
        cornerSize = newCornerSize
        baseFont = .monospacedSystemFont(ofSize: newGlyphSize, weight: .semibold)
        headFont = .monospacedSystemFont(ofSize: newGlyphSize + 1.5, weight: .heavy)
        layoutSignature = signature
        rebuildStreams(for: bounds, glyphSize: newGlyphSize, reduceMotion: reduceMotion)
    }

    func advance(by deltaTime: CGFloat, reduceMotion: Bool) {
        guard !streams.isEmpty else { return }

        let motionScale: CGFloat = reduceMotion ? 0.10 : 1.0

        for index in streams.indices {
            streams[index].head += streams[index].speed * deltaTime * motionScale
            streams[index].shuffleCountdown -= deltaTime

            if streams[index].head > streams[index].resetOffset {
                resetStream(at: index)
            } else if streams[index].shuffleCountdown <= 0 {
                shuffleGlyphs(at: index, headOnly: reduceMotion)
            }
        }
    }

    func draw(in context: CGContext, bounds: CGRect, reduceMotion: Bool) {
        context.saveGState()
        drawEdgeVeil(in: context, bounds: bounds)

        for edge in [Edge.top, .right, .bottom, .left] {
            context.saveGState()
            context.clip(to: rect(for: edge, bounds: bounds))
            drawStreams(
                streams.lazy.filter { $0.kind.matches(edge) },
                in: context,
                bounds: bounds,
                reduceMotion: reduceMotion
            )
            context.restoreGState()
        }

        for corner in [Corner.topLeft, .topRight, .bottomLeft, .bottomRight] {
            context.saveGState()
            context.clip(to: rect(for: corner, bounds: bounds))
            drawStreams(
                streams.lazy.filter { $0.kind.matches(corner) },
                in: context,
                bounds: bounds,
                reduceMotion: reduceMotion
            )
            context.restoreGState()
        }

        context.restoreGState()
    }
}

private extension MatrixRainRenderer {

    private func rebuildStreams(for bounds: CGRect, glyphSize: CGFloat, reduceMotion: Bool) {
        streams.removeAll()

        let edgeSpacing = glyphSize * 2.45
        let tailCount = reduceMotion ? 3 : 6
        let speedScale: CGFloat = reduceMotion ? 0.52 : 1.0

        for edge in [Edge.top, .bottom] {
            let trackCount = max(12, Int(ceil(bounds.width / edgeSpacing)))
            let length = bandWidth + glyphSize * CGFloat(tailCount + 2)
            appendEdgeStreams(
                edge: edge,
                trackCount: trackCount,
                crossLength: bounds.width,
                depthCount: 2,
                glyphSize: glyphSize,
                tailCount: tailCount,
                movementLength: length,
                speedScale: speedScale
            )
        }

        for edge in [Edge.left, .right] {
            let trackCount = max(18, Int(ceil(bounds.height / edgeSpacing)))
            let length = bandWidth + glyphSize * CGFloat(tailCount + 2)
            appendEdgeStreams(
                edge: edge,
                trackCount: trackCount,
                crossLength: bounds.height,
                depthCount: 2,
                glyphSize: glyphSize,
                tailCount: tailCount,
                movementLength: length,
                speedScale: speedScale
            )
        }

        for corner in [Corner.topLeft, .topRight, .bottomLeft, .bottomRight] {
            appendCornerStreams(
                corner: corner,
                trackCount: max(7, Int(ceil(cornerSize / (glyphSize * 1.42)))),
                glyphSize: glyphSize,
                tailCount: max(4, tailCount - 1),
                movementLength: cornerSize + glyphSize * CGFloat(tailCount + 2),
                speedScale: speedScale
            )
        }
    }

    private func appendEdgeStreams(
        edge: Edge,
        trackCount: Int,
        crossLength: CGFloat,
        depthCount: Int,
        glyphSize: CGFloat,
        tailCount: Int,
        movementLength: CGFloat,
        speedScale: CGFloat
    ) {
        let edgeInset = glyphSize * 0.45
        let usableCrossLength = max(crossLength - edgeInset * 2, glyphSize)

        for track in 0..<trackCount {
            let crossRatio = trackCount > 1 ? CGFloat(track) / CGFloat(trackCount - 1) : 0.5
            let crossOffset = edgeInset + usableCrossLength * crossRatio + CGFloat.random(in: -2...2)

            for depth in 0..<depthCount {
                guard depth == 0 || Double.random(in: 0...1) > 0.34 else { continue }

                let depthOffset = CGFloat(depth) * glyphSize * 0.94 + CGFloat.random(in: 0...(glyphSize * 0.28))
                let speed = CGFloat.random(in: 22...46) * speedScale
                let glyphCount = max(3, tailCount - depth / 2)
                let start = CGFloat.random(in: -movementLength...0)
                let stream = makeStream(
                    kind: .edge(edge),
                    crossOffset: crossOffset,
                    depthOffset: depthOffset,
                    glyphSize: glyphSize,
                    glyphCount: glyphCount,
                    speed: speed,
                    resetOffset: movementLength,
                    start: start
                )
                streams.append(stream)
            }
        }
    }

    private func appendCornerStreams(
        corner: Corner,
        trackCount: Int,
        glyphSize: CGFloat,
        tailCount: Int,
        movementLength: CGFloat,
        speedScale: CGFloat
    ) {
        let usableSize = cornerSize - glyphSize

        for track in 0..<trackCount {
            let ratio = trackCount > 1 ? CGFloat(track) / CGFloat(trackCount - 1) : 0.5
            let crossOffset = glyphSize * 0.45 + usableSize * ratio + CGFloat.random(in: -2...2)
            let speed = CGFloat.random(in: 18...39) * speedScale
            let stream = makeStream(
                kind: .corner(corner),
                crossOffset: crossOffset,
                depthOffset: CGFloat.random(in: 0...(glyphSize * 0.7)),
                glyphSize: glyphSize,
                glyphCount: tailCount,
                speed: speed,
                resetOffset: movementLength,
                start: CGFloat.random(in: -movementLength...0)
            )
            streams.append(stream)
        }
    }

    private func makeStream(
        kind: StreamKind,
        crossOffset: CGFloat,
        depthOffset: CGFloat,
        glyphSize: CGFloat,
        glyphCount: Int,
        speed: CGFloat,
        resetOffset: CGFloat,
        start: CGFloat
    ) -> RainStream {
        RainStream(
            kind: kind,
            crossOffset: crossOffset,
            depthOffset: depthOffset,
            glyphSize: glyphSize,
            glyphSpacing: glyphSize * CGFloat.random(in: 1.05...1.32),
            glyphCount: glyphCount,
            speed: speed,
            resetOffset: resetOffset,
            wobble: CGFloat.random(in: 0.6...2.2),
            phase: CGFloat.random(in: 0...(.pi * 2)),
            head: start,
            glyphs: makeGlyphs(count: glyphCount),
            shuffleCountdown: CGFloat.random(in: 0.12...0.42)
        )
    }

    private func resetStream(at index: Int) {
        streams[index].head = CGFloat.random(in: -(streams[index].resetOffset * 0.72)...0)
        streams[index].glyphs = makeGlyphs(count: streams[index].glyphCount)
        streams[index].shuffleCountdown = CGFloat.random(in: 0.12...0.44)
    }

    private func shuffleGlyphs(at index: Int, headOnly: Bool) {
        if headOnly {
            streams[index].glyphs[0] = randomGlyph()
        } else {
            for glyphIndex in streams[index].glyphs.indices {
                guard glyphIndex == 0 || Double.random(in: 0...1) > 0.42 else { continue }
                streams[index].glyphs[glyphIndex] = randomGlyph()
            }
        }

        streams[index].shuffleCountdown = CGFloat.random(in: 0.12...0.44)
    }

    private func drawStreams<VisibleStreams: Sequence>(
        _ visibleStreams: VisibleStreams,
        in context: CGContext,
        bounds: CGRect,
        reduceMotion: Bool
    ) where VisibleStreams.Element == RainStream {
        for stream in visibleStreams {
            for index in 0..<stream.glyphCount {
                let distance = stream.head - CGFloat(index) * stream.glyphSpacing
                guard distance > -stream.glyphSpacing else { continue }

                let alpha = alpha(forGlyphAt: index, count: stream.glyphCount, reduceMotion: reduceMotion)
                guard alpha > 0.01 else { continue }

                let point = glyphPoint(
                    for: stream,
                    distance: distance,
                    bounds: bounds
                )
                drawGlyph(stream.glyphs[index], at: point, index: index, alpha: alpha, reduceMotion: reduceMotion)
            }
        }
    }

    private func glyphPoint(for stream: RainStream, distance: CGFloat, bounds: CGRect) -> CGPoint {
        let wobble = sin((distance / 18) + stream.phase) * stream.wobble

        switch stream.kind {
        case .edge(.top):
            return CGPoint(
                x: stream.crossOffset + wobble,
                y: stream.depthOffset + distance
            )
        case .edge(.bottom):
            return CGPoint(
                x: stream.crossOffset + wobble,
                y: bounds.height - stream.depthOffset - distance - stream.glyphSize
            )
        case .edge(.left):
            return CGPoint(
                x: stream.depthOffset + distance,
                y: stream.crossOffset + wobble
            )
        case .edge(.right):
            return CGPoint(
                x: bounds.width - stream.depthOffset - distance - stream.glyphSize,
                y: stream.crossOffset + wobble
            )
        case .corner(.topLeft):
            return CGPoint(
                x: stream.crossOffset * 0.42 + distance * 0.54 + wobble,
                y: stream.depthOffset + distance * 0.72
            )
        case .corner(.topRight):
            return CGPoint(
                x: bounds.width - stream.crossOffset * 0.42 - distance * 0.54 - stream.glyphSize - wobble,
                y: stream.depthOffset + distance * 0.72
            )
        case .corner(.bottomLeft):
            return CGPoint(
                x: stream.crossOffset * 0.42 + distance * 0.54 + wobble,
                y: bounds.height - stream.depthOffset - distance * 0.72 - stream.glyphSize
            )
        case .corner(.bottomRight):
            return CGPoint(
                x: bounds.width - stream.crossOffset * 0.42 - distance * 0.54 - stream.glyphSize - wobble,
                y: bounds.height - stream.depthOffset - distance * 0.72 - stream.glyphSize
            )
        }
    }

    private func drawGlyph(
        _ glyph: String,
        at point: CGPoint,
        index: Int,
        alpha: CGFloat,
        reduceMotion: Bool
    ) {
        let isHead = index == 0
        let color = isHead
            ? UIColor(red: 0.78, green: 1.00, blue: 0.78, alpha: reduceMotion ? alpha * 0.55 : alpha)
            : UIColor(red: 0.13, green: 1.00, blue: 0.30, alpha: reduceMotion ? alpha * 0.45 : alpha)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: isHead ? headFont : baseFont,
            .foregroundColor: color
        ]

        if isHead, !reduceMotion {
            let glowAttributes: [NSAttributedString.Key: Any] = [
                .font: headFont,
                .foregroundColor: UIColor(red: 0.38, green: 1.00, blue: 0.45, alpha: alpha * 0.24)
            ]
            glyph.draw(at: CGPoint(x: point.x - 0.8, y: point.y - 0.8), withAttributes: glowAttributes)
            glyph.draw(at: CGPoint(x: point.x + 0.8, y: point.y + 0.8), withAttributes: glowAttributes)
        }

        glyph.draw(at: point, withAttributes: attributes)
    }

    private func drawEdgeVeil(in context: CGContext, bounds: CGRect) {
        context.saveGState()

        let topGradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [
                UIColor.black.withAlphaComponent(0.14).cgColor,
                UIColor.black.withAlphaComponent(0.00).cgColor
            ] as CFArray,
            locations: [0, 1]
        )
        let sideGradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [
                UIColor.black.withAlphaComponent(0.09).cgColor,
                UIColor.black.withAlphaComponent(0.00).cgColor
            ] as CFArray,
            locations: [0, 1]
        )

        if let topGradient {
            context.drawLinearGradient(
                topGradient,
                start: CGPoint(x: bounds.midX, y: 0),
                end: CGPoint(x: bounds.midX, y: bandWidth),
                options: []
            )
            context.drawLinearGradient(
                topGradient,
                start: CGPoint(x: bounds.midX, y: bounds.maxY),
                end: CGPoint(x: bounds.midX, y: bounds.maxY - bandWidth),
                options: []
            )
        }

        if let sideGradient {
            context.drawLinearGradient(
                sideGradient,
                start: CGPoint(x: 0, y: bounds.midY),
                end: CGPoint(x: bandWidth, y: bounds.midY),
                options: []
            )
            context.drawLinearGradient(
                sideGradient,
                start: CGPoint(x: bounds.maxX, y: bounds.midY),
                end: CGPoint(x: bounds.maxX - bandWidth, y: bounds.midY),
                options: []
            )
        }

        context.restoreGState()
    }

    private func alpha(forGlyphAt index: Int, count: Int, reduceMotion: Bool) -> CGFloat {
        let trailProgress = CGFloat(index) / CGFloat(max(count - 1, 1))
        let base = index == 0 ? CGFloat(0.58) : max(0.07, 0.34 * pow(1 - trailProgress, 1.45))
        return reduceMotion ? min(base, 0.16) : base
    }

    private func rect(for edge: Edge, bounds: CGRect) -> CGRect {
        switch edge {
        case .top:
            return CGRect(x: 0, y: 0, width: bounds.width, height: bandWidth)
        case .right:
            return CGRect(x: bounds.width - bandWidth, y: 0, width: bandWidth, height: bounds.height)
        case .bottom:
            return CGRect(x: 0, y: bounds.height - bandWidth, width: bounds.width, height: bandWidth)
        case .left:
            return CGRect(x: 0, y: 0, width: bandWidth, height: bounds.height)
        }
    }

    private func rect(for corner: Corner, bounds: CGRect) -> CGRect {
        switch corner {
        case .topLeft:
            return CGRect(x: 0, y: 0, width: cornerSize, height: cornerSize)
        case .topRight:
            return CGRect(x: bounds.width - cornerSize, y: 0, width: cornerSize, height: cornerSize)
        case .bottomLeft:
            return CGRect(x: 0, y: bounds.height - cornerSize, width: cornerSize, height: cornerSize)
        case .bottomRight:
            return CGRect(x: bounds.width - cornerSize, y: bounds.height - cornerSize, width: cornerSize, height: cornerSize)
        }
    }

    private func edgeBandWidth(for bounds: CGRect) -> CGFloat {
        min(max(min(bounds.width, bounds.height) * 0.145, 52), 86)
    }

    private func glyphSize(for bounds: CGRect) -> CGFloat {
        min(max(min(bounds.width, bounds.height) * 0.031, 11.5), 15.5)
    }

    private func makeGlyphs(count: Int) -> [String] {
        (0..<count).map { _ in randomGlyph() }
    }

    private func randomGlyph() -> String {
        String(symbols.randomElement() ?? "0")
    }
}
