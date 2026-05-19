import ActivityKit
import SwiftUI
import WidgetKit

struct ScanCodeLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ScanLiveActivityAttributes.self) { context in
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    appIconImage
                        .frame(width: 34, height: 34)
                        .clipShape(.rect(cornerRadius: 9))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.state.title)
                            .font(.system(size: 16, weight: .heavy))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        Text(context.state.subtitle)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.72))
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)
                }

                HStack(spacing: 8) {
                    liveActivityChip(title: "扫码", action: .scanner, isPrimary: context.state.action == .scanner)
                    liveActivityChip(title: "微信", action: .weChatScanner, isPrimary: context.state.action == .weChatScanner)
                    liveActivityChip(title: "支付宝", action: .alipayScanner, isPrimary: context.state.action == .alipayScanner)
                }
            }
            .padding(16)
            .containerBackground(for: .widget) {
                liveActivityBackground
            }
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    appIconImage
                        .frame(width: 28, height: 28)
                        .clipShape(.rect(cornerRadius: 7))
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 8) {
                        liveActivityChip(title: "扫码", action: .scanner, isPrimary: context.state.action == .scanner)
                        liveActivityChip(title: "微信", action: .weChatScanner, isPrimary: context.state.action == .weChatScanner)
                        liveActivityChip(title: "支付宝", action: .alipayScanner, isPrimary: context.state.action == .alipayScanner)
                    }
                }
            } compactLeading: {
                appIconImage
                    .frame(width: 20, height: 20)
                    .clipShape(.rect(cornerRadius: 5))
            } compactTrailing: {
                Image(systemName: "qrcode.viewfinder")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
            } minimal: {
                appIconImage
                    .frame(width: 18, height: 18)
                    .clipShape(.rect(cornerRadius: 4))
            }
            .widgetURL(context.state.action.url)
            .keylineTint(.cyan)
        }
    }
}

private extension ScanCodeLiveActivityWidget {

    func liveActivityChip(title: String, action: ScanAppAction, isPrimary: Bool) -> some View {
        Link(destination: action.url) {
            HStack(spacing: 6) {
                Image(systemName: action.symbolName)
                    .font(.system(size: 11, weight: .bold))

                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .lineLimit(1)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .glassEffect(
            isPrimary ? .regular.tint(.white.opacity(0.12)).interactive() : .regular.tint(.white.opacity(0.05)).interactive(),
            in: .capsule
        )
    }

    var appIconImage: some View {
        Image("ScanCodeIcon")
            .resizable()
            .scaledToFit()
    }

    var liveActivityBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.08, blue: 0.12),
                Color(red: 0.07, green: 0.25, blue: 0.27),
                Color(red: 0.18, green: 0.14, blue: 0.32)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(alignment: .top) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.14), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 42)
        }
    }
}
