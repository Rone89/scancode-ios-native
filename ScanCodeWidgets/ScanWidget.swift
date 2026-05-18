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
        .description("支持打开扫码页、微信扫一扫和支付宝扫码。")
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

    var body: some View {
        switch family {
        case .systemSmall:
            systemSmall
        case .systemMedium:
            systemMedium
        case .systemLarge:
            systemLarge
        case .systemExtraLarge:
            systemLarge
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

    private var systemSmall: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            GlassEffectContainer(spacing: 14) {
                VStack(spacing: 10) {
                    compactAction(entry.actions[0], prominent: true)
                    compactAction(entry.actions[1], prominent: false)
                }
            }
        }
        .padding(16)
        .containerBackground(for: .widget) {
            backgroundGradient
        }
    }

    private var systemMedium: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            GlassEffectContainer(spacing: 16) {
                HStack(spacing: 12) {
                    ForEach(entry.actions, id: \.rawValue) { action in
                        actionCard(action)
                    }
                }
            }
        }
        .padding(16)
        .containerBackground(for: .widget) {
            backgroundGradient
        }
    }

    private var systemLarge: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            Text("原生 AVFoundation 扫码、小组件直达微信扫一扫、支付宝扫码，以及聚合码分发。")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.86))

            GlassEffectContainer(spacing: 18) {
                VStack(spacing: 12) {
                    ForEach(entry.actions, id: \.rawValue) { action in
                        expandedActionRow(action)
                    }
                }
            }
        }
        .padding(18)
        .containerBackground(for: .widget) {
            backgroundGradient
        }
    }

    private var accessoryInline: some View {
        Text("ScanCode 扫码")
            .widgetURL(ScanAppAction.scanner.url)
    }

    private var accessoryCircular: some View {
        Image(systemName: "qrcode.viewfinder")
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(.white)
            .padding(10)
            .glassEffect(.regular.interactive(), in: Circle())
            .widgetURL(ScanAppAction.scanner.url)
            .containerBackground(for: .widget) {
                backgroundGradient
            }
    }

    private var accessoryRectangular: some View {
        HStack(spacing: 8) {
            Image(systemName: "qrcode.viewfinder")
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text("ScanCode")
                    .font(.system(size: 14, weight: .bold))
                Text("点按打开扫码页")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .widgetURL(ScanAppAction.scanner.url)
        .containerBackground(for: .widget) {
            backgroundGradient
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "qrcode.viewfinder")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 2) {
                Text("ScanCode")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)

                Text("iOS 26 原生液态玻璃扫码")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.82))
            }

            Spacer(minLength: 0)
        }
    }

    private func actionCard(_ action: ScanAppAction) -> some View {
        Link(destination: action.url) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: action.symbolName)
                    .font(.system(size: 20, weight: .semibold))
                Text(action.title)
                    .font(.system(size: 14, weight: .bold))
                Text(action.subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.78))
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
            .padding(14)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 22))
    }

    private func expandedActionRow(_ action: ScanAppAction) -> some View {
        Link(destination: action.url) {
            HStack(spacing: 12) {
                Image(systemName: action.symbolName)
                    .font(.system(size: 19, weight: .semibold))
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 3) {
                    Text(action.title)
                        .font(.system(size: 15, weight: .bold))

                    Text(action.subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.tint(.white.opacity(0.08)).interactive(), in: .rect(cornerRadius: 24))
    }

    private func compactAction(_ action: ScanAppAction, prominent: Bool) -> some View {
        Link(destination: action.url) {
            HStack(spacing: 10) {
                Image(systemName: action.symbolName)
                    .font(.system(size: 16, weight: .semibold))

                Text(action.title)
                    .font(.system(size: 14, weight: .bold))
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .glassEffect(
            prominent ? .regular.tint(.white.opacity(0.10)).interactive() : .regular.interactive(),
            in: .rect(cornerRadius: 20)
        )
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.12, green: 0.17, blue: 0.28),
                Color(red: 0.11, green: 0.34, blue: 0.42),
                Color(red: 0.15, green: 0.18, blue: 0.36)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
