# Sketchybar

`sketchybarrc` loads `helpers/` and then `init.lua`, which sets up the bar and the items in `items/init.lua`:

- left: apple, smhkd, menus, spaces, yabai, front_app
- right: calendar, battery, wifi, weather, sleep, cpu

## Dependencies

- The Lua module `~/.local/share/sketchybar_lua/sketchybar.so` comes from nixpkgs `sbarlua`, linked by `sketchybar.nix`. Without it the bar does not start.
- sketchybar is built from the fork in `modules/overlays/sketchybar.nix`. `typographical_width` in `default.lua` is merged upstream (FelixKratz/SketchyBar#826) but not yet in a release, so the stock nixpkgs build lacks it.

## Helpers

- The C helpers in `event_providers`, `menus`, and `symbol_image` are built by `sketchybar.nix` and linked to `~/.local/share/sketchybar_helpers/`. After editing their sources, run `just switch`. Compile errors show in the switch output, and runtime errors, Lua ones included, go to `/tmp/sketchybar_eric.err.log`.
- `helpers/symbols.lua` caches each rendered PNG in `~/.cache/sketchybar/symbols/` and renders only when the file is missing. After changing `symbol_image.m`, delete the cached PNGs there.
- `battery.lua` and `sleep.lua` run `sudo pmset`. That works only for the exact commands allowed NOPASSWD in `modules/features/base/darwin.nix`.
- `wifi/` holds the JXA scripts behind the wifi item. See [Wifi](#wifi).
- `app_icons.lua` loads the icon map from the `sketchybar-app-font` package, linked by `sketchybar.nix`, so names match the installed font.

## Wifi

`helpers/wifi/status.js` feeds the bar item in `items/wifi.lua`, and `helpers/wifi/scan.js` its network popup.

### Getting network names without Location Services

macOS 14.4+ hides SSIDs from processes without Location Services access.

- `ipconfig getsummary en0` prints `SSID : <redacted>`. `sudo ipconfig sethidewifiinfo 0` unhides it (stored as `HideWiFiInfo` in `/Library/Preferences/SystemConfiguration/com.apple.IPConfiguration.control.plist`). `ipconfig setverbose 1` does not.
- `networksetup -getairportnetwork en0` says "You are not associated with an AirPort network."
- `system_profiler SPAirPortDataType` has the current SSID but takes 12-24s. It lists nearby names only after `sethidewifiinfo 0`, and gives signal for the connected network only.
- CoreWLAN (`CWWiFiClient`) in a compiled binary returns `ssid nil` and `nil` scan names. Signal (`rssiValue`) and known networks (`configuration.networkProfiles`) work without permission. Ad-hoc signing a binary with an Apple-looking identifier does not help.
- Apple-signed interpreters get names. `osascript -l JavaScript` (JXA) and the Xcode `swift` interpreter both return scan names, even when launched by sketchybar.
- The private CoreWiFi framework (`/System/Library/PrivateFrameworks/CoreWiFi.framework`) through JXA gives everything with the default `HideWiFiInfo`: `CWFInterface.networkName` is the current SSID, `currentScanResult.signalStrength` its signal. Load the bundle and use `$.NSClassFromString("CWFInterface")`, since JXA does not expose it as `$.CWFInterface`.
- A helper `.app` holding Location permission was the other route. It was never needed.

### Scanning

- `CWFInterface.performScanWithParametersError` with a `CWFScanParameters` scans the radio in about 12s.
- `CWFScanParameters.setCacheOnly(true)` returns the system's recent results in about 0.1s. Show those first, then replace them with a full scan.
- Each `CWFScanResult` has `networkName`, `RSSI`, `signalStrength`, `isOpen`, `isPersonalHotspot`. Cellular type and phone battery of a hotspot are not available.
- Known networks come from CoreWLAN `configuration.networkProfiles`.

### Signal bars

- `signalStrength` is `(RSSI + 90) / 60`. This fit all 26 results of one scan.
- The SF Symbol `wifi` takes a variable value. Arcs light above 0, from 0.338 to 0.340, and from 0.678 to 0.680. In RSSI that is 1 bar above -90, 2 at -69 and above, 3 at -49 and above.
- Pass `signalStrength` straight to the symbol so the cutoffs are Apple's own.

### Popup actions

- Join a known network: `networksetup -setairportnetwork en0 '<ssid>'`. It blocks until joined, so show `progress.indicator` on the row meanwhile.
- Not wired yet, Wi-Fi on and off: `networksetup -setairportpower en0 on|off`. CoreWiFi also has `setPower:error:` and `associateWithParameters:`.
- Wi-Fi Settings: `open "x-apple.systempreferences:com.apple.wifi-settings-extension"` (`/System/Library/ExtensionKit/Extensions/Wi-Fi.appex`).
- Control Center's own menu bar items cannot be mirrored with a sketchybar alias here. Only third-party status items show up in `sketchybar --query default_menu_items`.
