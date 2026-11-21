# SwiftRust URL Scheme

Open a device using `swiftrust://connect?id=DEVICE&mode=desktop`. Normal authentication still applies. Do not put secrets in links.

| Parameter | Values / default |
| --- | --- |
| id | Required remote ID, host, IP or host:port; percent-encode special characters |
| mode | desktop (default), terminal, files, camera |
| relay | true/false or 1/0, default false |
| approval | Request remote approval, default false |
| connect | Default true; false only pre-fills device information without connecting |
| newWindow | Default false; true requests a new scene when the OS supports multiple windows |

Examples:

```text
swiftrust://connect?id=160111967
swiftrust://connect?id=mac.local&mode=terminal&newWindow=1
swiftrust://connect?id=192.168.1.10%3A21118&mode=files
swiftrust://connect?id=%5Bfd7a%3A115c%3Aa1e0%3A%3A1%5D%3A21118&mode=desktop
```

Unknown/duplicate parameters and password/Auth-key parameters are rejected. Existing connections are not silently replaced. The old rustdesk:// scheme retains its ID-fill behavior.

## Home Screen icons and actual workflow import

Device menu → Add to Home Screen → Copy Device ID and Import Template exports an actual signed .shortcut file for the selected connection mode, relay and new-window options. Choose Shortcuts in the system share sheet; if unavailable, Save to Files and tap the saved file. Paste the copied remote ID into the import question and confirm Add Shortcut. Then choose Add to Home Screen and select the exported larger icon or a custom photo. Clipboard copying is local-only and expires after ten minutes.

The bundled templates are generic and signed before app distribution. The app copies the signed bytes unchanged, because editing the ID directly inside a signed workflow would invalidate it. There is no donation-only success message, Safari handoff or Siri voice-recording UI. Final import and Home Screen confirmation remain user actions.

The workflow contains SwiftRust's native Connect Device action, which hands off directly to the app scene. The 16 templates cover all four modes and relay/new-window combinations. Their source/signing command is in `scripts/ios/build-shortcut-templates.py`. Regenerating needs macOS Shortcuts; Apple validates only the placeholder template, not user device IDs. No signing server is required at runtime.

Mac import preview and bundled file/export checks pass. Actual iOS import/action resolution still needs device verification. Web Clip generation was removed in build 109 and Add Voice Shortcut in 110. Old Web Clip profiles must be removed manually in Settings → General → VPN & Device Management.

## Windows

Device menu → Connect in New Window opens an independent scene. Use the system's window/split-view controls to arrange it. Availability is controlled by UIApplication.supportsMultipleScenes; turning on the manifest flag does not force unsupported hardware or system software to offer split screen. Each window's remote session, input, frames, terminal tabs and file jobs have separate routing. Settings → URL Scheme reports current system capability.
