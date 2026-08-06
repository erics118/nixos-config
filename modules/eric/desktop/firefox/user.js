// Required by the managed userChrome.css and fx-autoconfig scripts.
user_pref("sidebar.revamp", true);
// Let the sidebar panels (Sidebery, history/bookmarks/synced) show the vibrancy
// painted on #browser, instead of the browser element's opaque backing.
user_pref("browser.tabs.allow_transparent_browser", true);
// macOS vibrancy behind the chrome, see the vibrancy block in userChrome.css.
// Firefox 154 defaults browser.theme.native-theme to false, which makes the
// -moz-native-theme media feature false and stops any NSVisualEffectView from
// being created, so no appearance rule can produce blur without this.
user_pref("browser.theme.native-theme", true);
// behind-window blurs the desktop behind Firefox rather than only within the window.
user_pref("widget.macos.titlebar-blend-mode.behind-window", true);
user_pref("widget.macos.sidebar-blend-mode.behind-window", true);
user_pref("svg.context-properties.content.enabled", true);
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
user_pref("userChromeJS.enabled", true);
user_pref("userChromeJS.experimental.enabled", true);
// Re-run @include DOMContentLoaded scripts on every panel reload, not just the
// first. Lets compact-sidebar-panel.uc.js run without a JSWindowActor.
user_pref("userChromeJS.persistent_domcontent_callback", true);
user_pref("userChromeJS.firstRunShown", true);
user_pref("userChromeJS.scriptsDisabled", "");
