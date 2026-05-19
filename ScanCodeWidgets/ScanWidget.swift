import SwiftUI
import WidgetKit

struct ScanWidgetEntry: TimelineEntry {
    let date: Date
    let actions: [ScanAppAction]
}

struct ScanWidgetProvider: TimelineProvider {

    func placeholder(in context: Context) -> ScanWidgetEntry {
        ScanWidgetEntry(date: .now, actions: ScanAppAction.allCases)
    }

    func getSnapshot(in context: Context, completion: @escaping (ScanWidgetEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ScanWidgetEntry>) -> Void) {
        let entry = ScanWidgetEntry(date: .now, actions: ScanAppAction.allCases)
        completion(Timeline(entries: [entry], policy: .never))
    }
}

struct ScanWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.codex.scancode.quick-actions", provider: ScanWidgetProvider()) { entry in
            ScanWidgetView(entry: entry)
        }
        .configurationDisplayName("ScanCode 快捷扫码")
        .description("从桌面或锁屏快速打开扫码、微信扫一扫和支付宝扫码。")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .systemExtraLarge,
            .accessoryInline,
            .accessoryCircular,
            .accessoryRectangular
        ])
    }
}

private struct ScanWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: ScanWidgetEntry

    private var scannerAction: ScanAppAction {
        entry.actions.first(where: { $0 == .scanner }) ?? .scanner
    }

    private var quickActions: [ScanAppAction] {
        entry.actions.filter { $0 != .scanner }
    }

    var body: some View {
        switch family {
        case .systemSmall:
            systemSmall
        case .systemMedium:
            systemMedium
        case .systemLarge:
            systemLarge
        case .systemExtraLarge:
            systemExtraLarge
        case .accessoryInline:
            accessoryInline
        case .accessoryCircular:
            accessoryCircular
        case .accessoryRectangular:
            accessoryRectangular
        @unknown default:
            systemSmall
        }
    }
}

private extension ScanWidgetView {

    var systemSmall: some View {
        ZStack(alignment: .bottomTrailing) {
            backgroundDecoration

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    appIconImage
                        .frame(width: 34, height: 34)
                        .clipShape(.rect(cornerRadius: 9))

                    Spacer(minLength: 0)

                    Image(systemName: "viewfinder")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white.opacity(0.78))
                }

                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: 4) {
                    Text("ScanCode")
                        .font(.system(size: 19, weight: .heavy))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text("点按立即扫码")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.76))
                        .lineLimit(1)
                }
            }
        }
        .widgetURL(scannerAction.url)
        .padding(16)
        .containerBackground(for: .widget) {
            backgroundGradient
        }
    }

    var systemMedium: some View {
        HStack(spacing: 12) {
            Link(destination: scannerAction.url) {
                heroPanel(compact: true)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)

            VStack(spacing: 10) {
                ForEach(quickActions, id: \.rawValue) { action in
                    compactAction(action)
                }
            }
            .frame(width: 124)
        }
        .padding(14)
        .containerBackground(for: .widget) {
            backgroundGradient
        }
    }

    var systemLarge: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            Link(destination: scannerAction.url) {
                heroPanel(compact: false)
            }
            .buttonStyle(.plain)

            VStack(spacing: 10) {
                ForEach(quickActions, id: \.rawValue) { action in
                    expandedActionRow(action)
                }
            }
        }
        .padding(16)
        .containerBackground(for: .widget) {
            backgroundGradient
        }
    }

    var systemExtraLarge: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 14) {
                header

                Link(destination: scannerAction.url) {
                    heroPanel(compact: false)
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 12) {
                Text("快捷入口")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white.opacity(0.78))

                ForEach(quickActions, id: \.rawValue) { action in
                    expandedActionRow(action)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(18)
        .containerBackground(for: .widget) {
            backgroundGradient
        }
    }

    var accessoryInline: some View {
        Text("ScanCode 扫码")
            .widgetURL(scannerAction.url)
    }

    var accessoryCircular: some View {
        ZStack {
            Circle()
                .fill(.white.opacity(0.12))

            appIconImage
                .frame(width: 34, height: 34)
                .clipShape(Circle())
        }
        .glassEffect(.regular.interactive(), in: Circle())
        .widgetURL(scannerAction.url)
        .containerBackground(for: .widget) {
            backgroundGradient
        }
    }

    var accessoryRectangular: some View {
        HStack(spacing: 8) {
            appIconImage
                .frame(width: 28, height: 28)
                .clipShape(.rect(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 1) {
                Text("ScanCode")
                    .font(.system(size: 14, weight: .bold))
                    .lineLimit(1)

                Text("快速打开扫码")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .widgetURL(scannerAction.url)
        .containerBackground(for: .widget) {
            backgroundGradient
        }
    }

    var header: some View {
        HStack(spacing: 10) {
            appIconImage
                .frame(width: 34, height: 34)
                .clipShape(.rect(cornerRadius: 9))

            VStack(alignment: .leading, spacing: 2) {
                Text("ScanCode")
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text("扫码、微信、支付宝")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Image(systemName: "qrcode.viewfinder")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white.opacity(0.82))
                .frame(width: 34, height: 34)
                .glassEffect(.regular.tint(.white.opacity(0.08)), in: Circle())
        }
    }

    func heroPanel(compact: Bool) -> some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.white.opacity(0.08))

            scannerRings
                .frame(width: compact ? 76 : 116, height: compact ? 76 : 116)
                .opacity(compact ? 0.46 : 0.52)
                .offset(x: compact ? 20 : 22, y: compact ? 18 : 20)

            VStack(alignment: .leading, spacing: compact ? 8 : 12) {
                HStack {
                    actionBadge(scannerAction, size: compact ? 32 : 40)

                    Spacer(minLength: 0)

                    Image(systemName: "arrow.up.right")
                        .font(.system(size: compact ? 12 : 13, weight: .heavy))
                        .foregroundStyle(.white.opacity(0.76))
                }

                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: 4) {
                    Text("立即扫码")
                        .font(.system(size: compact ? 17 : 22, weight: .heavy))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text("识别二维码和聚合码")
                        .font(.system(size: compact ? 11 : 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.74))
                        .lineLimit(compact ? 2 : 1)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(compact ? 14 : 16)
        }
        .frame(maxWidth: .infinity, minHeight: compact ? 130 : 150)
        .glassEffect(.regular.tint(.white.opacity(0.08)).interactive(), in: .rect(cornerRadius: 24))
    }

    func compactAction(_ action: ScanAppAction) -> some View {
        Link(destination: action.url) {
            HStack(spacing: 8) {
                actionBadge(action, size: 26)

                VStack(alignment: .leading, spacing: 2) {
                    Text(shortTitle(for: action))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text(shortSubtitle(for: action))
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.64))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.tint(.white.opacity(0.06)).interactive(), in: .rect(cornerRadius: 18))
    }

    func expandedActionRow(_ action: ScanAppAction) -> some View {
        Link(destination: action.url) {
            HStack(spacing: 12) {
                actionBadge(action, size: 36)

                VStack(alignment: .leading, spacing: 3) {
                    Text(action.title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text(action.subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(.white.opacity(0.48))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.tint(.white.opacity(0.06)).interactive(), in: .rect(cornerRadius: 22))
    }

    func actionBadge(_ action: ScanAppAction, size: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(badgeGradient(for: action))

            actionIcon(action)
                .frame(width: size * 0.58, height: size * 0.58)
        }
        .frame(width: size, height: size)
        .shadow(color: badgeShadow(for: action), radius: 10, x: 0, y: 5)
    }

    @ViewBuilder
    func actionIcon(_ action: ScanAppAction) -> some View {
        if action == .scanner {
            appIconImage
                .clipShape(.rect(cornerRadius: 5))
        } else {
            Image(systemName: action.symbolName)
                .resizable()
                .scaledToFit()
                .foregroundStyle(.white)
        }
    }

    var appIconImage: some View {
        Image("ScanCodeIcon")
            .resizable()
            .scaledToFit()
    }

    var scannerRings: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.20), lineWidth: 1)
            Circle()
                .stroke(.cyan.opacity(0.20), lineWidth: 8)
                .padding(12)
            Circle()
                .stroke(.white.opacity(0.10), lineWidth: 18)
                .padding(26)
        }
    }

    var backgroundDecoration: some View {
        ZStack(alignment: .bottomTrailing) {
            scannerRings
                .frame(width: 104, height: 104)
                .opacity(0.42)
                .offset(x: 32, y: 34)
        }
    }

    var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.08, blue: 0.12),
                Color(red: 0.07, green: 0.25, blue: 0.27),
                Color(red: 0.18, green: 0.14, blue: 0.32)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(alignment: .topTrailing) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.16), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 44)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.18)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 76)
        }
    }

    func badgeGradient(for action: ScanAppAction) -> LinearGradient {
        let colors: [Color]
        switch action {
        case .scanner:
            colors = [
                Color(red: 0.28, green: 0.78, blue: 0.88),
                Color(red: 0.18, green: 0.40, blue: 0.92)
            ]
        case .weChatScanner:
            colors = [
                Color(red: 0.24, green: 0.82, blue: 0.38),
                Color(red: 0.08, green: 0.54, blue: 0.28)
            ]
        case .alipayScanner:
            colors = [
                Color(red: 0.22, green: 0.62, blue: 1.00),
                Color(red: 0.12, green: 0.32, blue: 0.90)
            ]
        }

        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    func badgeShadow(for action: ScanAppAction) -> Color {
        switch action {
        case .scanner:
            return .cyan.opacity(0.22)
        case .weChatScanner:
            return .green.opacity(0.20)
        case .alipayScanner:
            return .blue.opacity(0.22)
        }
    }

    func shortTitle(for action: ScanAppAction) -> String {
        switch action {
        case .scanner:
            return "扫码"
        case .weChatScanner:
            return "微信"
        case .alipayScanner:
            return "支付宝"
        }
    }

    func shortSubtitle(for action: ScanAppAction) -> String {
        switch action {
        case .scanner:
            return "识别"
        case .weChatScanner:
            return "扫一扫"
        case .alipayScanner:
            return "扫码"
        }
    }
}
