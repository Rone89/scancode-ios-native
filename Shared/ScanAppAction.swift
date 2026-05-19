import Foundation

enum ScanAppAction: String, CaseIterable, Sendable, Codable, Hashable {
    case scanner = "startscan"
    case weChatScanner = "wechat-scanner"
    case alipayScanner = "alipay-scanner"
    case openAlipay = "open-alipay"
    case weChatPayCode = "wechat-pay-code"
    case alipayPayCode = "alipay-pay-code"

    static let scheme = "scancode"
    static let scanWidgetActions: [ScanAppAction] = [.scanner, .weChatScanner, .alipayScanner]

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
        case Self.openAlipay.rawValue:
            self = .openAlipay
        case Self.weChatPayCode.rawValue:
            self = .weChatPayCode
        case Self.alipayPayCode.rawValue:
            self = .alipayPayCode
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
            return "扫码"
        case .weChatScanner:
            return "微信扫一扫"
        case .alipayScanner:
            return "支付宝扫码"
        case .openAlipay:
            return "打开支付宝"
        case .weChatPayCode:
            return "微信付款码"
        case .alipayPayCode:
            return "支付宝付款码"
        }
    }

    var subtitle: String {
        switch self {
        case .scanner:
            return "识别二维码和聚合码"
        case .weChatScanner:
            return "启动微信扫码入口"
        case .alipayScanner:
            return "启动支付宝扫码入口"
        case .openAlipay:
            return "启动支付宝客户端"
        case .weChatPayCode:
            return "启动微信付款码入口"
        case .alipayPayCode:
            return "启动支付宝付款码入口"
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
        case .openAlipay:
            return "a.circle"
        case .weChatPayCode:
            return "qrcode"
        case .alipayPayCode:
            return "barcode.viewfinder"
        }
    }
}
