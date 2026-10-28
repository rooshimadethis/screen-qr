# Screen QR

Small native macOS 14+ launch-and-exit utility. No dependencies or background service.

- `Sources/ScreenQR.swift` uses ScreenCaptureKit to capture each visible display, Vision to decode QR codes, and NSWorkspace to open HTTP(S) URLs in the default browser.
- Every trigger waits three seconds before capture so the user can switch windows. Images and decoded values stay in memory; never log/save screen contents or QR payloads, which can contain credentials.
- One URL opens immediately; multiple URLs use a hostname-only native chooser; non-web codes show a generic message. Reject raw hidden control characters, URL credentials, and other schemes. URL paths, queries, fragments, and arbitrary payloads must never appear in labels or logs. Screen recording permission belongs to the app bundle; launch the installed app, not its binary, for live checks.
- `ScreenQR.xcodeproj` builds the host and a macOS 26+ WidgetKit extension. `Sources/ScanScreenIntent.swift` is compiled into both targets; its OpenIntent launches the host, which owns capture permission. `Controls/ScanQRControl.swift` exposes the native Scan QR Code button.
- `bash scripts/build.sh` builds/signs both targets, verifies signatures/plists, and runs real Vision decoding on generated QR images plus URL validation and blank-image checks. `bash scripts/install.sh --update` stages and verifies a complete replacement, preserves the previous app under build/backups, and restores the old installation if the replacement move fails. It registers the extension and keeps the Desktop symlink. Never merge app bundles with ditto during an update: stale executables invalidate the sealed signature.
- macOS screen capture permission and live display capture/browser opening require a separate interactive acceptance check. Build/self-test does not prove these.
- No commits, pushes, or repository initialization without explicit authorization.

- Host and extension enable hardened runtime; the extension is sandboxed. Builds use local ad-hoc signing, not notarization. No external dependencies/lockfiles are present. See SECURITY.md for review boundaries and the intentional browser-networking risk from automatic opening.
- The user confirmed the native Control Center button and scanning worked before the publication security changes. Synthetic tests cover the updated URL/label policy; do not treat them as live browser or OS-permission verification.
