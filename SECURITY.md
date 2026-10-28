# Security and privacy

## Data handling

Screen QR captures each currently visible display after a three-second delay. Apple ScreenCaptureKit supplies the image and Vision decodes QR codes locally. The app's custom code keeps images and decoded payloads in memory for that invocation and does not write them to disk, log them, collect telemetry, or upload them. Non-web payloads are not displayed. Link chooser labels show the host only, omitting potentially private paths, queries, and fragments.

These are statements about this app's code, not guarantees about macOS memory paging, crash diagnostics, the default browser's history/sync, or other software on the Mac. Screen Recording access can be revoked in System Settings. The sandboxed WidgetKit extension only launches the host app and does not receive screenshots or QR payloads.

## URL trust boundary

One detected web link opens automatically, as the utility's intended behavior. Only HTTP and HTTPS URLs with a nonempty host are accepted. Embedded credentials, raw control characters, backslashes, and decoded controls or URL delimiters in hostnames are rejected. No QR payload is executed as a command or passed to a shell.

This is not a phishing, malware, or URL-reputation filter. A QR code can reference a malicious website, a local/private-network service, or a URL whose visit triggers an action. HTTP is unencrypted. The browser receives the complete URL and can send its usual network information and cookies to the destination. Use Screen QR with trusted QR codes and rely on your browser's security protections when navigating.

## Build and installation

There are no third-party package dependencies or package lockfiles. Both targets use Apple's SDKs, enable hardened runtime, and are locally ad-hoc signed. The Control Center extension is sandboxed. Builds are not Developer ID signed or notarized; source publication does not provide Apple's notarization assurance.

The installer stages and verifies a complete replacement before moving an existing app, preserves the old bundle in a unique backup directory, and attempts rollback if the final replacement move fails. It refuses symlink install destinations and unrelated app identifiers. Build output, backups, Xcode user data, and common credential file patterns are excluded by `.gitignore`; publication should additionally use an explicit source-file list.

## Review scope

A source review on 2026-10-28 covered screen capture, QR/URL processing, UI payload exposure, App Intent routing, entitlements and signing settings, installer replacement, and publication contents. It led to removal of URL paths from chooser labels, strict rejection of raw hidden controls, hardened-runtime enablement, safer installer replacement, and publication ignore rules. Focused regression checks cover URL rejection and private labels in addition to decoding generated QR images.

This is a scoped engineering review, not a formal security audit or a guarantee that the application has no vulnerabilities. It does not establish website safety, notarization, or behavior on every macOS version and hardware configuration.

## Reporting

For ordinary bugs, use a GitHub issue. For security reports, do not post screenshots, QR payloads, credentials, or private destination URLs publicly. Use the repository's private vulnerability reporting feature if available. Otherwise open an issue requesting a private contact channel without disclosing the vulnerability or sensitive data.
