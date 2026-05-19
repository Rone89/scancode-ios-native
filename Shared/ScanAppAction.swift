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
}
