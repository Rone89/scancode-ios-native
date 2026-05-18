import ActivityKit
import SwiftUI
import WidgetKit

struct ScanCodeLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ScanLiveActivityAttributes.self) { context in
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    appIconImage
                        .frame(width: 32, height: 32)
                        .clipShape(.rect(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.state.title)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                        Text(context.state.subtitle)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.82))
                    }
                }

                HStack(spacing: 10) {
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
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 10) {
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
                Text("扫")
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

    private func liveActivityChip(title: String, action: ScanAppAction, isPrimary: Bool) -> some View {
        Link(destination: action.url) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .glassEffect(
            isPrimary ? .regular.tint(.white.opacity(0.10)).interactive() : .regular.interactive(),
            in: .capsule
        )
    }

    private var appIconImage: some View {
        Image("ScanCodeIcon")
            .resizable()
            .scaledToFit()
    }

    private var liveActivityBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.09, green: 0.16, blue: 0.30),
                Color(red: 0.10, green: 0.31, blue: 0.44),
                Color(red: 0.15, green: 0.18, blue: 0.34)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
