import Foundation

enum ScanAppAction: String, CaseIterable, Sendable, Codable, Hashable {
    case scanner = "startscan"
    case weChatScanner = "wechat-scanner"
    case alipayScanner = "alipay-scanner"

    static let scheme = "scancode"

    init?(url: URL) {
        guard url.scheme?.lowercased() == Self.scheme else { return nil }

        let hostToken = url.host?.lowercased()
        let pathToken = url.pathComponents.dropFirst().first?.lowercased()
        let lastPathComponent = url.lastPathComponent.lowercased()
        let fallbackToken = lastPathComponent.isEmpty ? nil : lastPathComponent
        let token: String?
        if let hostToken {
            token = hostToken
        } else if let pathToken {
            token = pathToken
        } else {
            token = fallbackToken
        }

        guard let token else { return nil }

        switch token {
        case Self.scanner.rawValue, "scanner":
            self = .scanner
        case Self.weChatScanner.rawValue:
            self = .weChatScanner
        case Self.alipayScanner.rawValue:
            self = .alipayScanner
        default:
            return nil
        }
    }

    var url: URL {
        URL(string: "\(Self.scheme)://\(rawValue)")!
    }

    var widgetDeepLink: String {
        url.absoluteString
    }

    var title: String {
        switch self {
        case .scanner:
            return "打开扫码"
        case .weChatScanner:
            return "微信扫一扫"
        case .alipayScanner:
            return "支付宝扫码"
        }
    }

    var subtitle: String {
        switch self {
        case .scanner:
            return "回到原生扫码页"
        case .weChatScanner:
            return "直达微信扫一扫"
        case .alipayScanner:
            return "直达支付宝扫码"
        }
    }

    var symbolName: String {
        switch self {
        case .scanner:
            return "qrcode.viewfinder"
        case .weChatScanner:
            return "message.fill"
        case .alipayScanner:
            return "creditcard.fill"
        }
    }
}
