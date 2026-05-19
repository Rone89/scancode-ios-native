import SwiftUI
import WidgetKit

@main
struct ScanCodeWidgetsBundle: WidgetBundle {
    var body: some Widget {
        ScanWidget()
        PaymentQuickWidget()
        ShortcutGridWidget()
        ScanCodeLiveActivityWidget()
    }
}
