import ActivityKit
import Foundation

struct ScanLiveActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var title: String
        var subtitle: String
        var action: ScanAppAction
    }

    var startedAt: Date
}
