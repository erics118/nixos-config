# wifi helpers

`status.js` feeds the bar item in `items/wifi.lua`, and `scan.js` its network popup.

## Getting network names without Location Services

macOS 14.4+ hides SSIDs from processes without Location Services access.

- `ipconfig getsummary en0` prints `SSID : <redacted>`. `sudo ipconfig sethidewifiinfo 0` unhides it (stored as `HideWiFiInfo` in `/Library/Preferences/SystemConfiguration/com.apple.IPConfiguration.control.plist`). `ipconfig setverbose 1` does not.
- `networksetup -getairportnetwork en0` says "You are not associated with an AirPort network."
- `system_profiler SPAirPortDataType` has the current SSID but takes 12-24s. It lists nearby names only after `sethidewifiinfo 0`, and gives signal for the connected network only.
- CoreWLAN (`CWWiFiClient`) in a compiled binary returns `ssid nil` and `nil` scan names. Signal (`rssiValue`) and known networks (`configuration.networkProfiles`) work without permission. Ad-hoc signing a binary with an Apple-looking identifier does not help.
- Apple-signed interpreters get names. `osascript -l JavaScript` (JXA) and the Xcode `swift` interpreter both return scan names, even when launched by sketchybar.
- The private CoreWiFi framework (`/System/Library/PrivateFrameworks/CoreWiFi.framework`) through JXA gives everything with the default `HideWiFiInfo`: `CWFInterface.networkName` is the current SSID, `currentScanResult.signalStrength` its signal. Load the bundle and use `$.NSClassFromString("CWFInterface")`, since JXA does not expose it as `$.CWFInterface`.
- A helper `.app` holding Location permission was the other route. It was never needed.

## Scanning

- `CWFInterface.performScanWithParametersError` with a `CWFScanParameters` scans the radio in about 12s.
- `CWFScanParameters.setCacheOnly(true)` returns the system's recent results in about 0.1s. Show those first, then replace them with a full scan.
- Each `CWFScanResult` has `networkName`, `RSSI`, `signalStrength`, `isOpen`, `isPersonalHotspot`. Cellular type and phone battery of a hotspot are not available.
- Known networks come from CoreWLAN `configuration.networkProfiles`.

## Signal bars

- `signalStrength` is `(RSSI + 90) / 60`. This fit all 26 results of one scan.
- The SF Symbol `wifi` takes a variable value. Arcs light above 0, from 0.338 to 0.340, and from 0.678 to 0.680. In RSSI that is 1 bar above -90, 2 at -69 and above, 3 at -49 and above.
- Pass `signalStrength` straight to the symbol so the cutoffs are Apple's own.

## Popup actions

- Join a known network: `networksetup -setairportnetwork en0 '<ssid>'`. It blocks until joined, so show `progress.indicator` on the row meanwhile.
- Wi-Fi on and off: `networksetup -setairportpower en0 on|off`. CoreWiFi also has `setPower:error:` and `associateWithParameters:`.
- Wi-Fi Settings: `open "x-apple.systempreferences:com.apple.wifi-settings-extension"` (`/System/Library/ExtensionKit/Extensions/Wi-Fi.appex`).
- Control Center's own menu bar items cannot be mirrored with a sketchybar alias here. Only third-party status items show up in `sketchybar --query default_menu_items`.
