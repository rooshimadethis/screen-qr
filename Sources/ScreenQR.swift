import AppKit
import ScreenCaptureKit
import Vision
import CoreImage

// Images and decoded payloads stay in memory for the duration of one scan.
enum QRReader {
    static func payloads(in image: CGImage) throws -> [String] {
        let request = VNDetectBarcodesRequest()
        request.symbologies = [.qr]
        try VNImageRequestHandler(cgImage: image).perform([request])
        return (request.results ?? []).sorted {
            if abs($0.boundingBox.midY - $1.boundingBox.midY) > 0.05 {
                return $0.boundingBox.midY > $1.boundingBox.midY
            }
            return $0.boundingBox.midX < $1.boundingBox.midX
        }.compactMap(\.payloadStringValue)
    }

    static func webURL(_ payload: String) -> URL? {
        // Reject hidden controls before URLComponents can normalize/percent-encode them.
        guard !payload.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains),
              !payload.contains("\\") else { return nil }
        let text = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.contains(where: { $0.isWhitespace || $0.isNewline }),
              let parts = URLComponents(string: text),
              let scheme = parts.scheme?.lowercased(),
              ["https", "http"].contains(scheme),
              let host = parts.host, !host.isEmpty,
              !host.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains),
              !host.contains(where: { $0.isWhitespace || "/\\?#@".contains($0) }),
              parts.user == nil, parts.password == nil else { return nil }
        return parts.url
    }

    static func linkLabel(_ url: URL, index: Int) -> String {
        // Paths, queries, and fragments can all contain private login/reset tokens.
        "\(index + 1). \(url.host ?? "Web link")"
    }

    static func unique(_ payloads: [String]) -> [String] {
        var seen = Set<String>()
        return payloads.filter { seen.insert($0).inserted }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var scanning = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        startScan()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        startScan()
        return false
    }

    private func startScan() {
        guard !scanning else { return }
        scanning = true
        Task {
            defer { NSApp.terminate(nil) }
            guard CGPreflightScreenCaptureAccess() else {
                _ = CGRequestScreenCaptureAccess()
                let answer = alert("Allow Screen Recording", "Screen QR needs permission to read QR codes on your displays.\n\nIn System Settings → Privacy & Security → Screen & System Audio Recording, enable Screen QR. Then launch Screen QR again.\n\nScreenshots are processed locally and never saved.", buttons: ["Open Settings", "Cancel"])
                if answer == .alertFirstButtonReturn,
                   let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                    NSWorkspace.shared.open(url)
                }
                return
            }
            // Give the user time to switch to the window containing the QR code.
            try? await Task.sleep(for: .seconds(3))
            do {
                let result = try await captureAndRead()
                present(result.payloads, failedDisplays: result.failures)
            } catch {
                alert("Couldn’t Scan the Screen", "Check Screen QR’s screen recording permission and try again.\n\n\(error.localizedDescription)")
            }
        }
    }

    private func captureAndRead() async throws -> (payloads: [String], failures: Int) {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard !content.displays.isEmpty else {
            throw NSError(domain: "ScreenQR", code: 1, userInfo: [NSLocalizedDescriptionKey: "No visible displays are available."])
        }
        let ownApps = content.applications.filter { $0.processID == ProcessInfo.processInfo.processIdentifier }
        var payloads: [String] = []
        var failures = 0
        for display in content.displays {
            do {
                let filter = SCContentFilter(display: display, excludingApplications: ownApps, exceptingWindows: [])
                let config = SCStreamConfiguration()
                config.width = Int(CGDisplayPixelsWide(display.displayID))
                config.height = Int(CGDisplayPixelsHigh(display.displayID))
                config.showsCursor = false
                let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
                // Vision work runs off the UI thread.
                let decoded = try await Task.detached { try QRReader.payloads(in: image) }.value
                payloads.append(contentsOf: decoded)
            } catch {
                failures += 1
            }
        }
        return (QRReader.unique(payloads), failures)
    }

    private func present(_ payloads: [String], failedDisplays: Int) {
        let partial = failedDisplays > 0 ? "\n\n\(failedDisplays) display(s) couldn’t be scanned. Try again if the code was on another display." : ""
        let urls = QRReader.unique(payloads.compactMap { QRReader.webURL($0)?.absoluteString }).compactMap(URL.init(string:))
        guard !urls.isEmpty else {
            if payloads.isEmpty {
                alert(failedDisplays > 0 ? "Scan Incomplete" : "No QR Code Found", "Make sure the QR code is visible and large enough, then launch Screen QR again." + partial)
            } else {
                // Do not echo arbitrary payloads: they can contain Wi-Fi passwords or login tokens.
                alert("No Web Link Found", "Found \(payloads.count) QR code(s), but none contains an HTTP or HTTPS link. Screen QR opens web links only." + partial)
            }
            return
        }
        if failedDisplays > 0 {
            guard alert("Some Displays Couldn’t Be Scanned", "Found \(urls.count) web link(s) on the displays that were scanned." + partial, buttons: ["Continue", "Cancel"]) == .alertFirstButtonReturn else { return }
        }
        if urls.count == 1 {
            open(urls[0])
            return
        }
        let chooser = NSAlert()
        chooser.messageText = "Choose a QR Link"
        chooser.informativeText = "Found \(urls.count) different web links. Choose one to open in your default browser."
        chooser.addButton(withTitle: "Open Link")
        chooser.addButton(withTitle: "Cancel")
        let list = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 440, height: 28))
        // Hosts are enough for the chooser; full URLs can contain private tokens.
        for (index, url) in urls.enumerated() {
            list.addItem(withTitle: QRReader.linkLabel(url, index: index))
        }
        chooser.accessoryView = list
        NSApp.activate(ignoringOtherApps: true)
        if chooser.runModal() == .alertFirstButtonReturn { open(urls[list.indexOfSelectedItem]) }
    }

    private func open(_ url: URL) {
        if !NSWorkspace.shared.open(url) {
            alert("Couldn’t Open the Link", "Check that a default web browser is set in System Settings, then try again.")
        }
    }

    @discardableResult
    private func alert(_ title: String, _ message: String, buttons: [String] = ["OK"]) -> NSApplication.ModalResponse {
        let dialog = NSAlert()
        dialog.messageText = title
        dialog.informativeText = message
        for button in buttons { dialog.addButton(withTitle: button) }
        NSApp.activate(ignoringOtherApps: true)
        return dialog.runModal()
    }
}

func selfTest() throws {
    func check(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() { throw NSError(domain: "ScreenQR.Tests", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
    }
    let context = CIContext()
    for payload in ["https://example.com/qr-test", "Just ordinary text", "WIFI:T:WPA;S:TestNetwork;P:synthetic-test-only;;"] {
        let filter = CIFilter(name: "CIQRCodeGenerator")!
        filter.setValue(Data(payload.utf8), forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        let qr = filter.outputImage!.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        let canvas = qr.extent.insetBy(dx: -40, dy: -40)
        let padded = qr.composited(over: CIImage(color: .white).cropped(to: canvas))
        let image = context.createCGImage(padded, from: canvas)!
        let decoded = try QRReader.payloads(in: image)
        try check(decoded == [payload], "QR round-trip failed")
    }
    let blank = context.createCGImage(CIImage(color: .white).cropped(to: CGRect(x: 0, y: 0, width: 500, height: 500)), from: CGRect(x: 0, y: 0, width: 500, height: 500))!
    let blankPayloads = try QRReader.payloads(in: blank)
    try check(blankPayloads.isEmpty, "Blank image returned a QR code")
    try check(QRReader.unique(["a", "b", "a"]) == ["a", "b"], "Duplicate suppression failed")
    try check(QRReader.webURL("https://example.com/a?b=c") != nil, "HTTPS rejected")
    try check(QRReader.webURL("HTTP://example.com") != nil, "HTTP rejected")
    for invalid in ["javascript:alert(1)", "file:///etc/hosts", "mailto:test@example.com", "WIFI:S:test;;", "https:///", "https://user:pass@example.com", "https://exa mple.com", "ordinary text"] {
        try check(QRReader.webURL(invalid) == nil, "Non-web or malformed payload accepted")
    }
    for control in ["\u{0000}", "\u{0009}", "\u{000A}", "\u{000D}", "\u{007F}", "\u{0085}", "\u{202E}"] {
        try check(QRReader.webURL("https://example.com/a" + control + "b") == nil, "URL containing a hidden control accepted")
        try check(QRReader.webURL(control + "https://example.com") == nil, "Leading control normalized away")
    }
    for ambiguous in ["https://exa%09mple.com", "https://exa%0Ample.com", "https://example.com\\@other.example", "https://user%3Avalue@example.com", "https://%2f%2fexample.com"] {
        try check(QRReader.webURL(ambiguous) == nil, "Ambiguous authority accepted")
    }
    try check(QRReader.webURL("https://example.com/a%20b") != nil, "Valid encoded URL path rejected")
    try check(QRReader.webURL("http://127.0.0.1:8080/local") != nil, "Intentional local HTTP support rejected")
    let privateURL = URL(string: "https://example.com/reset/synthetic-path-token?code=synthetic-query-token#synthetic-fragment-token")!
    try check(QRReader.linkLabel(privateURL, index: 0) == "1. example.com", "Chooser exposed a URL path, query, or fragment")
    print("PASS: generated QR images, blank image, URL validation, control rejection, private link labels, and deduplication")
}

@main
struct ScreenQRMain {
    @MainActor
    static func main() {
        if CommandLine.arguments.contains("--self-test") {
            do { try selfTest() } catch {
                fputs("Self-test failed: \(error.localizedDescription)\n", stderr)
                exit(1)
            }
        } else {
            let app = NSApplication.shared
            let delegate = AppDelegate()
            app.delegate = delegate
            app.run()
        }
    }
}
