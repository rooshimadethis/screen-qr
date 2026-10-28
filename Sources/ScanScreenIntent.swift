import AppIntents

// Compiled into both targets so the system routes the control to the host app.
struct ScanScreenIntent: OpenIntent {
    static var title: LocalizedStringResource = "Scan Screen QR"
    static var description = IntentDescription("Open Screen QR and scan your displays after a three-second delay.")

    @Parameter(title: "Action")
    var target: ScreenQRAction

    init() { target = .scan }
}

enum ScreenQRAction: String, AppEnum {
    case scan
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Screen QR Action")
    static var caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .scan: DisplayRepresentation(title: "Scan QR Code")
    ]
}
