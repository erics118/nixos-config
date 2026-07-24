// Required by the managed userChrome.css and fx-autoconfig scripts.
user_pref("sidebar.revamp", true);
// Let the transparent native sidebar panels (history/bookmarks/synced) show the
// --atbc-raised-surface painted on #sidebar-box, instead of the browser's opaque backing.
// user_pref("browser.tabs.allow_transparent_browser", true);
user_pref("svg.context-properties.content.enabled", true);
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
user_pref("userChromeJS.enabled", true);
user_pref("userChromeJS.experimental.enabled", true);
// Re-run @include DOMContentLoaded scripts on every panel reload, not just the
// first. Lets compact-sidebar-panel.uc.js run without a JSWindowActor.
user_pref("userChromeJS.persistent_domcontent_callback", true);
user_pref("userChromeJS.firstRunShown", true);
user_pref("userChromeJS.scriptsDisabled", "");
