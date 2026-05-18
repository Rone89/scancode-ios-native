import Foundation
import Darwin
import SwiftUI

struct AppleIntelligenceGlowOverlay: View {

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Color.clear
            if reduceMotion {
                glowFrame(time: 0, motionAmount: 0)
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
                    glowFrame(
                        time: timeline.date.timeIntervalSinceReferenceDate,
                        motionAmount: 1
                    )
                }
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
        .accessibilityHidden(true)
        .background(Color.clear)
    }

    private func glowFrame(time: TimeInterval, motionAmount: Double) -> some View {
        GeometryReader { proxy in
            let shortestSide = max(1, min(proxy.size.width, proxy.size.height))
            let cornerRadius = max(34, shortestSide * 0.09)
            let softLineWidth = max(24, shortestSide * 0.06)
            let haloLineWidth = max(10, shortestSide * 0.026)
            let crispLineWidth = max(2, shortestSide * 0.006)
            let primaryStartDegrees = time * 34 * motionAmount
            let secondaryStartDegrees = 160 - time * 18 * motionAmount
            let shimmerOffset = CGFloat(sin(time * 0.72 * motionAmount)) * proxy.size.width * 0.12

            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        edgeGradient(startDegrees: primaryStartDegrees),
                        lineWidth: softLineWidth
                    )
                    .blur(radius: max(16, shortestSide * 0.035))
                    .opacity(reduceMotion ? 0.12 : 0.20)
                    .padding(-softLineWidth / 2)

                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        edgeGradient(startDegrees: secondaryStartDegrees),
                        lineWidth: haloLineWidth
                    )
                    .blur(radius: max(8, shortestSide * 0.018))
                    .opacity(reduceMotion ? 0.16 : 0.26)
                    .padding(-haloLineWidth / 2)

                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        glassHighlightGradient(startDegrees: primaryStartDegrees + 28),
                        lineWidth: crispLineWidth
                    )
                    .blur(radius: 1.2)
                    .opacity(reduceMotion ? 0.28 : 0.40)
                    .padding(1)

                edgeSheen(proxy: proxy, offset: shimmerOffset)
                    .opacity(reduceMotion ? 0.08 : 0.12)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
    }

    private func edgeGradient(startDegrees: Double) -> AngularGradient {
        AngularGradient(
            gradient: Gradient(stops: [
                .init(color: Color(red: 0.18, green: 0.68, blue: 1.00).opacity(0.00), location: 0.00),
                .init(color: Color(red: 0.20, green: 0.72, blue: 1.00).opacity(0.78), location: 0.10),
                .init(color: Color(red: 0.76, green: 0.36, blue: 1.00).opacity(0.62), location: 0.28),
                .init(color: Color(red: 1.00, green: 0.36, blue: 0.78).opacity(0.58), location: 0.46),
                .init(color: Color(red: 0.24, green: 1.00, blue: 0.84).opacity(0.66), location: 0.66),
                .init(color: Color(red: 1.00, green: 0.86, blue: 0.30).opacity(0.40), location: 0.80),
                .init(color: Color(red: 0.18, green: 0.68, blue: 1.00).opacity(0.00), location: 1.00)
            ]),
            center: .center,
            startAngle: .degrees(startDegrees),
            endAngle: .degrees(startDegrees + 360)
        )
    }

    private func glassHighlightGradient(startDegrees: Double) -> AngularGradient {
        AngularGradient(
            gradient: Gradient(stops: [
                .init(color: .white.opacity(0.00), location: 0.00),
                .init(color: .white.opacity(0.72), location: 0.08),
                .init(color: Color(red: 0.82, green: 0.96, blue: 1.00).opacity(0.34), location: 0.16),
                .init(color: .white.opacity(0.00), location: 0.31),
                .init(color: .white.opacity(0.24), location: 0.64),
                .init(color: .white.opacity(0.00), location: 1.00)
            ]),
            center: .center,
            startAngle: .degrees(startDegrees),
            endAngle: .degrees(startDegrees + 360)
        )
    }

    private func edgeSheen(proxy: GeometryProxy, offset: CGFloat) -> some View {
        let horizontalHeight = max(18, proxy.size.height * 0.035)
        let verticalWidth = max(18, proxy.size.width * 0.045)
        let horizontalGradient = LinearGradient(
            colors: [
                .clear,
                .white.opacity(0.42),
                Color(red: 0.58, green: 0.91, blue: 1.00).opacity(0.22),
                Color(red: 1.00, green: 0.60, blue: 0.92).opacity(0.20),
                .clear
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        let verticalGradient = LinearGradient(
            colors: [
                .clear,
                .white.opacity(0.28),
                Color(red: 0.62, green: 1.00, blue: 0.86).opacity(0.18),
                Color(red: 0.82, green: 0.56, blue: 1.00).opacity(0.16),
                .clear
            ],
            startPoint: .top,
            endPoint: .bottom
        )

        return ZStack {
            VStack(spacing: 0) {
                Rectangle()
                    .fill(horizontalGradient)
                    .frame(height: horizontalHeight)
                    .offset(x: offset)
                    .blur(radius: horizontalHeight * 0.28)

                Spacer(minLength: 0)

                Rectangle()
                    .fill(horizontalGradient)
                    .frame(height: horizontalHeight)
                    .offset(x: -offset * 0.8)
                    .blur(radius: horizontalHeight * 0.32)
            }

            HStack(spacing: 0) {
                Rectangle()
                    .fill(verticalGradient)
                    .frame(width: verticalWidth)
                    .offset(y: -offset * 0.5)
                    .blur(radius: verticalWidth * 0.34)

                Spacer(minLength: 0)

                Rectangle()
                    .fill(verticalGradient)
                    .frame(width: verticalWidth)
                    .offset(y: offset * 0.45)
                    .blur(radius: verticalWidth * 0.34)
            }
        }
    }
}
