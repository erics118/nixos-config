// Required by the managed userChrome.css and fx-autoconfig scripts.
user_pref("sidebar.revamp", true);
// platform theming: only needed for macOS vibrancy, and it makes system colors
// like buttonface resolve to macOS values instead of Firefox's own tokens
user_pref("browser.theme.native-theme", false);
// keep tab and sidebar canvases opaque, see .agents/skills/firefox-ui/gotchas.md
user_pref("browser.tabs.allow_transparent_browser", false);
user_pref("widget.macos.titlebar-blend-mode.behind-window", false);
user_pref("widget.macos.sidebar-blend-mode.behind-window", false);
user_pref("svg.context-properties.content.enabled", true);
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
user_pref("userChromeJS.enabled", true);
user_pref("userChromeJS.experimental.enabled", true);
// Re-run @include DOMContentLoaded scripts on every panel reload, not just the
// first. Lets compact-sidebar-panel.uc.js run without a JSWindowActor.
user_pref("userChromeJS.persistent_domcontent_callback", true);
user_pref("userChromeJS.firstRunShown", true);
user_pref("userChromeJS.scriptsDisabled", "");
// unload idle tabs under macOS memory pressure, non-nightly builds ship mask 0
user_pref("browser.lowMemoryResponseMask", 3);
user_pref("browser.lowMemoryResponseOnWarn", true);
// pinned tabs stay unloaded at startup until clicked
user_pref("browser.sessionstore.restore_pinned_tabs_on_demand", true);
