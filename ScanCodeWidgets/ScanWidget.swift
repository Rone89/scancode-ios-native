import AppIntents
import SwiftUI
import WidgetKit

struct ScanWidgetEntry: TimelineEntry {
    let date: Date
    let actions: [ScanAppAction]
}

struct ScanWidgetProvider: TimelineProvider {

    func placeholder(in context: Context) -> ScanWidgetEntry {
        ScanWidgetEntry(date: .now, actions: ScanAppAction.scanWidgetActions)
    }

    func getSnapshot(in context: Context, completion: @escaping (ScanWidgetEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ScanWidgetEntry>) -> Void) {
        let entry = ScanWidgetEntry(date: .now, actions: ScanAppAction.scanWidgetActions)
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
        .accessibilityHidden(true)
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
        case .openAlipay, .weChatPayCode, .alipayPayCode:
            colors = [
                Color(red: 0.24, green: 0.82, blue: 0.38),
                Color(red: 0.08, green: 0.54, blue: 0.28)
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
        case .openAlipay, .weChatPayCode, .alipayPayCode:
            return .green.opacity(0.20)
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
        case .openAlipay:
            return "支付宝"
        case .weChatPayCode:
            return "微信"
        case .alipayPayCode:
            return "付款码"
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
        case .openAlipay:
            return "打开"
        case .weChatPayCode:
            return "付款码"
        case .alipayPayCode:
            return "支付宝"
        }
    }
}

private struct PaymentQuickEntry: TimelineEntry {
    let date: Date
    let actions: [PaymentQuickAction]
}

private struct PaymentQuickProvider: TimelineProvider {

    func placeholder(in context: Context) -> PaymentQuickEntry {
        PaymentQuickEntry(date: .now, actions: PaymentQuickAction.allCases)
    }

    func getSnapshot(in context: Context, completion: @escaping (PaymentQuickEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PaymentQuickEntry>) -> Void) {
        let entry = PaymentQuickEntry(date: .now, actions: PaymentQuickAction.allCases)
        completion(Timeline(entries: [entry], policy: .never))
    }
}

struct PaymentQuickWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.codex.scancode.payment-quick-actions", provider: PaymentQuickProvider()) { entry in
            PaymentQuickWidgetView(entry: entry)
        }
        .configurationDisplayName("支付快捷入口")
        .description("从桌面快速打开 ScanCode、支付宝、微信付款码和支付宝付款码。")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}

private enum PaymentQuickAction: String, CaseIterable {
    case app
    case alipay
    case weChatPayCode
    case alipayPayCode

    var destination: URL {
        switch self {
        case .app:
            return ScanAppAction.scanner.url
        case .alipay:
            return URL(string: "alipays://")!
        case .weChatPayCode:
            return URL(string: "weixin://widget/pay")!
        case .alipayPayCode:
            return URL(string: "alipays://platformapi/startapp?appId=20000056")!
        }
    }

    var symbolName: String {
        switch self {
        case .app:
            return "qrcode.viewfinder"
        case .alipay:
            return "alipay"
        case .weChatPayCode:
            return "qrcode"
        case .alipayPayCode:
            return "qrcode"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .app:
            return "打开当前应用"
        case .alipay:
            return "打开支付宝"
        case .weChatPayCode:
            return "打开微信付款码"
        case .alipayPayCode:
            return "打开支付宝付款码"
        }
    }

    var backgroundColor: Color {
        switch self {
        case .app:
            return .white
        case .alipay:
            return Color(red: 0.008, green: 0.478, blue: 1.000)
        case .weChatPayCode:
            return Color(red: 0.035, green: 0.722, blue: 0.243)
        case .alipayPayCode:
            return Color(red: 0.008, green: 0.478, blue: 1.000)
        }
    }

    var foregroundColor: Color {
        switch self {
        case .app:
            return Color(red: 0.08, green: 0.10, blue: 0.12)
        case .alipay, .weChatPayCode, .alipayPayCode:
            return .white
        }
    }
}

private struct PaymentQuickWidgetView: View {
    let entry: PaymentQuickEntry

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        GeometryReader { proxy in
            let shortestSide = min(proxy.size.width, proxy.size.height)
            let side = max(46, shortestSide * 0.35)
            let gridSpacing = max(12, shortestSide * 0.08)
            let horizontalPadding = max(16, shortestSide * 0.11)
            let verticalPadding = max(15, shortestSide * 0.10)

            ZStack {
                background

                LazyVGrid(columns: columns, spacing: gridSpacing) {
                    ForEach(entry.actions, id: \.rawValue) { action in
                        Link(destination: action.destination) {
                            PaymentQuickButton(action: action, side: side)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(action.accessibilityLabel))
                    }
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, verticalPadding)
            }
        }
        .containerBackground(for: .widget) {
            Color.clear
        }
    }

    private var background: some View {
        RoundedRectangle(cornerRadius: 30, style: .continuous)
            .fill(.ultraThinMaterial)
            .opacity(0.72)
            .overlay {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.24),
                                .white.opacity(0.07),
                                .white.opacity(0.02)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.72),
                                .white.opacity(0.18),
                                .clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .overlay(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(.white.opacity(0.20), lineWidth: 0.8)
                    .blur(radius: 0.4)
            }
            .overlay(alignment: .top) {
                Capsule()
                    .fill(.white.opacity(0.30))
                    .frame(width: 86, height: 1.2)
                    .padding(.top, 8)
                    .blur(radius: 0.2)
            }
            .glassEffect(.regular.tint(.white.opacity(0.14)), in: .rect(cornerRadius: 30))
    }
}

private struct PaymentQuickButton: View {
    let action: PaymentQuickAction
    let side: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(action.backgroundColor)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            .white.opacity(action == .app ? 0.34 : 0.22),
                            .clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .center
                    )
                )

            PaymentQuickIcon(action: action, side: side)
        }
        .frame(width: side, height: side)
        .contentShape(Circle())
        .shadow(color: .black.opacity(0.16), radius: 7, x: 0, y: 5)
        .overlay {
            Circle()
                .stroke(.white.opacity(action == .app ? 0.78 : 0.28), lineWidth: 1)
        }
    }
}

private struct PaymentQuickIcon: View {
    let action: PaymentQuickAction
    let side: CGFloat

    var body: some View {
        Group {
            if action == .alipay {
                Text("支")
                    .font(.system(size: side * 0.43, weight: .heavy, design: .rounded))
                    .baselineOffset(side * 0.01)
            } else {
                Image(systemName: action.symbolName)
                    .font(.system(size: side * 0.36, weight: .semibold))
                    .symbolRenderingMode(.monochrome)
            }
        }
        .foregroundStyle(action.foregroundColor)
        .accessibilityHidden(true)
    }
}

struct ShortcutGridWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "com.codex.scancode.shortcut-grid",
            intent: ShortcutGridConfigurationIntent.self,
            provider: ShortcutGridProvider()
        ) { entry in
            ShortcutGridWidgetView(entry: entry)
        }
        .configurationDisplayName("快捷指令面板")
        .description("添加四个自定义快捷指令入口。")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}

struct ShortcutGridConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "快捷指令面板"
    static var description = IntentDescription("配置四个快捷指令名称，小组件会直接调起对应快捷指令。")

    @Parameter(title: "左上快捷指令")
    var topLeftShortcutName: String?

    @Parameter(title: "右上快捷指令")
    var topRightShortcutName: String?

    @Parameter(title: "左下快捷指令")
    var bottomLeftShortcutName: String?

    @Parameter(title: "右下快捷指令")
    var bottomRightShortcutName: String?
}

private struct ShortcutGridEntry: TimelineEntry {
    let date: Date
    let configuration: ShortcutGridConfigurationIntent
}

private struct ShortcutGridProvider: AppIntentTimelineProvider {

    func placeholder(in context: Context) -> ShortcutGridEntry {
        ShortcutGridEntry(date: .now, configuration: .preview)
    }

    func snapshot(
        for configuration: ShortcutGridConfigurationIntent,
        in context: Context
    ) async -> ShortcutGridEntry {
        ShortcutGridEntry(date: .now, configuration: configuration.withPreviewFallbacks)
    }

    func timeline(
        for configuration: ShortcutGridConfigurationIntent,
        in context: Context
    ) async -> Timeline<ShortcutGridEntry> {
        let entry = ShortcutGridEntry(date: .now, configuration: configuration.withPreviewFallbacks)
        return Timeline(entries: [entry], policy: .never)
    }
}

private extension ShortcutGridConfigurationIntent {

    static var preview: ShortcutGridConfigurationIntent {
        var configuration = ShortcutGridConfigurationIntent()
        configuration.topLeftShortcutName = "快捷指令 1"
        configuration.topRightShortcutName = "快捷指令 2"
        configuration.bottomLeftShortcutName = "快捷指令 3"
        configuration.bottomRightShortcutName = "快捷指令 4"
        return configuration
    }

    var withPreviewFallbacks: ShortcutGridConfigurationIntent {
        var configuration = self

        if configuration.topLeftShortcutName.normalizedShortcutName == nil {
            configuration.topLeftShortcutName = "快捷指令 1"
        }

        if configuration.topRightShortcutName.normalizedShortcutName == nil {
            configuration.topRightShortcutName = "快捷指令 2"
        }

        if configuration.bottomLeftShortcutName.normalizedShortcutName == nil {
            configuration.bottomLeftShortcutName = "快捷指令 3"
        }

        if configuration.bottomRightShortcutName.normalizedShortcutName == nil {
            configuration.bottomRightShortcutName = "快捷指令 4"
        }

        return configuration
    }
}

private extension Optional where Wrapped == String {

    var normalizedShortcutName: String? {
        guard let trimmed = self?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }

        return trimmed
    }
}

private enum ShortcutGridSlot: CaseIterable {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight

    var fallbackTitle: String {
        switch self {
        case .topLeft:
            return "快捷指令 1"
        case .topRight:
            return "快捷指令 2"
        case .bottomLeft:
            return "快捷指令 3"
        case .bottomRight:
            return "快捷指令 4"
        }
    }

    var symbolName: String {
        switch self {
        case .topLeft:
            return "bolt.fill"
        case .topRight:
            return "sparkles"
        case .bottomLeft:
            return "command"
        case .bottomRight:
            return "play.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .topLeft:
            return Color(red: 1.00, green: 0.72, blue: 0.18)
        case .topRight:
            return Color(red: 0.20, green: 0.68, blue: 1.00)
        case .bottomLeft:
            return Color(red: 0.52, green: 0.42, blue: 1.00)
        case .bottomRight:
            return Color(red: 0.12, green: 0.78, blue: 0.42)
        }
    }

    func shortcutName(from configuration: ShortcutGridConfigurationIntent) -> String {
        switch self {
        case .topLeft:
            return configuration.topLeftShortcutName.normalizedShortcutName ?? fallbackTitle
        case .topRight:
            return configuration.topRightShortcutName.normalizedShortcutName ?? fallbackTitle
        case .bottomLeft:
            return configuration.bottomLeftShortcutName.normalizedShortcutName ?? fallbackTitle
        case .bottomRight:
            return configuration.bottomRightShortcutName.normalizedShortcutName ?? fallbackTitle
        }
    }

    func shortcutURL(from configuration: ShortcutGridConfigurationIntent) -> URL {
        let shortcutName = shortcutName(from: configuration)
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        let encodedName = shortcutName.addingPercentEncoding(withAllowedCharacters: allowedCharacters) ?? shortcutName
        return URL(string: "shortcuts://run-shortcut?name=\(encodedName)")!
    }
}

private struct ShortcutGridWidgetView: View {
    let entry: ShortcutGridEntry

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        GeometryReader { proxy in
            let shortestSide = min(proxy.size.width, proxy.size.height)
            let gridSpacing = max(10, shortestSide * 0.075)
            let padding = max(12, shortestSide * 0.085)

            ZStack {
                ShortcutGridGlassBackground()

                LazyVGrid(columns: columns, spacing: gridSpacing) {
                    ForEach(ShortcutGridSlot.allCases, id: \.self) { slot in
                        Link(destination: slot.shortcutURL(from: entry.configuration)) {
                            ShortcutGridButton(
                                title: slot.shortcutName(from: entry.configuration),
                                symbolName: slot.symbolName,
                                accentColor: slot.accentColor
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text("运行\(slot.shortcutName(from: entry.configuration))"))
                    }
                }
                .padding(padding)
            }
        }
        .containerBackground(for: .widget) {
            Color.clear
        }
    }
}

private struct ShortcutGridButton: View {
    let title: String
    let symbolName: String
    let accentColor: Color

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: symbolName)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(
                    Circle()
                        .fill(accentColor)
                        .overlay {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.white.opacity(0.24), .clear],
                                        startPoint: .topLeading,
                                        endPoint: .center
                                    )
                                )
                        }
                )
                .shadow(color: accentColor.opacity(0.28), radius: 6, x: 0, y: 3)

            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(1)
                .minimumScaleFactor(0.62)
        }
        .frame(maxWidth: .infinity, minHeight: 54)
        .padding(.horizontal, 5)
        .padding(.vertical, 6)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.white.opacity(0.10))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(.white.opacity(0.14), lineWidth: 1)
                }
        }
        .glassEffect(.regular.tint(.white.opacity(0.05)), in: .rect(cornerRadius: 18))
        .contentShape(.rect(cornerRadius: 18))
    }
}

private struct ShortcutGridGlassBackground: View {

    var body: some View {
        RoundedRectangle(cornerRadius: 30, style: .continuous)
            .fill(.ultraThinMaterial)
            .opacity(0.74)
            .overlay {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.26),
                                .white.opacity(0.07),
                                .white.opacity(0.02)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.68),
                                .white.opacity(0.16),
                                .clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .glassEffect(.regular.tint(.white.opacity(0.12)), in: .rect(cornerRadius: 30))
    }
}
