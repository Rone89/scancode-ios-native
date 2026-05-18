import Foundation

enum ScanAppAction: String, CaseIterable, Sendable {
    case scanner = "scanner"
    case weChatScanner = "wechat-scanner"
    case alipayScanner = "alipay-scanner"

    static let scheme = "scancode"

    init?(url: URL) {
        guard url.scheme?.lowercased() == Self.scheme else { return nil }

        let token = url.host?.lowercased()
            ?? url.pathComponents.dropFirst().first?.lowercased()
            ?? url.lastPathComponent.lowercased()

        guard let token else { return nil }
        self.init(rawValue: token)
    }

    var url: URL {
        URL(string: "\(Self.scheme)://\(rawValue)")!
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
