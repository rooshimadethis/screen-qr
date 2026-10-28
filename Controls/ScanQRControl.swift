import AppIntents
import SwiftUI
import WidgetKit

struct ScanQRControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "local.rooshi.screenqr.scan") {
            ControlWidgetButton(action: ScanScreenIntent()) {
                Label("Scan QR Code", systemImage: "qrcode.viewfinder")
            }
        }
        .displayName("Scan QR Code")
        .description("Scan your screens after a three-second delay and open a QR web link.")
    }
}

@main
struct ScreenQRControls: WidgetBundle {
    var body: some Widget {
        ScanQRControl()
    }
}
