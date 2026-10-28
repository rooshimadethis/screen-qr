# Screen QR

Launch **Screen QR**, switch to the desired window during the **three-second delay**, and it scans QR codes on the currently visible displays and opens a web link in your default browser. Runs once and quits. Uses only Apple frameworks. The app does not upload screenshots, save screenshot files, run a persistent service, or include third-party dependencies.

## Install

The supported build/install path requires **macOS 26+ and Xcode 26+**, because it includes the native Control Center extension. The scanner host has a macOS 14 deployment target, but a separate host-only installer for older versions is not provided.

```sh
git clone https://github.com/rooshimadethis/screen-qr.git
cd screen-qr
bash scripts/install.sh
```

The app is installed in `~/Applications/Screen QR.app`, with a shortcut on the Desktop. For an update, run `bash scripts/install.sh --update`. The replacement is staged and signature-verified before changing the current installation. The previous app is preserved under `build/backups/`; a failed replacement move restores it.

On first launch, allow **Screen QR** in System Settings → Privacy & Security → Screen & System Audio Recording (called Screen Recording on older macOS versions), then launch it again. macOS may require quitting/reopening the app after granting permission.

One HTTP(S) link opens automatically. Several links show a chooser with hostnames only; private URL paths, queries, and fragments are not displayed. Other QR payloads (text, Wi-Fi setup, app links) are not opened or displayed. Duplicate QR payloads are collapsed. Only the visible desktop Spaces are scanned; hidden/minimized windows and protected content cannot be read. Enlarge very small QR codes if detection fails.

## Control Center on macOS Tahoe

1. Open Control Center → Edit Controls.
2. Select **Screen QR** in the left sidebar, or search for **Scan QR Code**.
3. Drag **Scan QR Code** into Control Center or the menu bar, then click Done.

Click the button, switch to the desired window, and the app captures the screen after three seconds. Every trigger uses the same delay. If the app already has a scan pending, further triggers are ignored until that scan finishes.

The extension uses WidgetKit and a shared App Intents `OpenIntent` to launch the host app; capture runs in the host, not in the extension. Screenshots are never stored or passed between processes.

For an optional keyboard shortcut, create an Apple Shortcut with **Open App → Screen QR**, then use its Details → **Add Keyboard Shortcut**.

## Verify

```sh
bash scripts/build.sh
```

This builds/signs the app and runs synthetic QR decoding, blank-image, URL policy, and duplicate tests. For end-to-end acceptance, put a web QR code on screen, launch the installed app, grant permission, and launch again. Verify the expected URL opens in your default browser. Repeat with two different codes and a display without codes. Multi-display and Control Center launch behavior need interactive verification.

## Privacy and security

Screen QR processes screenshots and QR payloads in memory. Its custom code does not save them, send them to a server, copy them to the clipboard, or collect telemetry. Only the host app captures screens; the sandboxed Control Center extension launches it. Screen Recording permission remains under macOS control and can be revoked in System Settings.

**Use with QR codes you trust.** The single-link automatic opening is intentional: a QR code can point to a malicious site, trigger a web action, or reference a local-network address. Screen QR checks the URL structure and allows HTTP(S) only; it does not assess website safety or block private-network destinations. HTTP links are unencrypted. Opening the URL sends a normal request through your browser, including its path/query and the browser's usual cookies and network information. Browser history, sync, OS diagnostics, and memory management are outside the app's control.

Builds are locally ad-hoc signed with hardened runtime; they are not Developer ID signed or notarized. This repository publishes source rather than a notarized installer. See [SECURITY.md](SECURITY.md) for the review scope and reporting guidance.
