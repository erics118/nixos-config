// ===== chrome customization =====

// Required by the managed userChrome.css and fx-autoconfig scripts.
user_pref("sidebar.revamp", true);
// platform theming: only needed for macOS vibrancy, and it makes system colors
// like buttonface resolve to macOS values instead of Firefox's own tokens
user_pref("browser.theme.native-theme", false);
// keep tab and sidebar canvases opaque, see .agents/skills/firefox-ui/gotchas.md
user_pref("browser.tabs.allow_transparent_browser", false);
// userChrome.css targets the Proton markup, and Firefox 158 defaults Nova on
user_pref("browser.nova.enabled", false);
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
// the sidebery fork is unsigned, and only developer edition honours this
user_pref("xpinstall.signatures.required", false);

// ===== behavior =====

// unload idle tabs under macOS memory pressure, non-nightly builds ship mask 0
user_pref("browser.lowMemoryResponseMask", 3);
user_pref("browser.lowMemoryResponseOnWarn", true);
// pages that name no font get sans-serif, which fontconfig maps to SF Pro on linux
user_pref("font.default.x-western", "sans-serif");
// pinned tabs stay unloaded at startup until clicked
user_pref("browser.sessionstore.restore_pinned_tabs_on_demand", true);
// show the full url, scheme and trailing slash included
user_pref("browser.urlbar.trimURLs", false);

// ===== ai features =====

// on-device ml engine, which runs the downloaded models in about:addons
user_pref("browser.ml.enable", false);
// history search by meaning, backed by a local embeddings model
user_pref("places.semanticHistory.featureGate", false);
user_pref("browser.ml.chat.enabled", false);
user_pref("browser.ml.linkPreview.enabled", false);
user_pref("browser.tabs.groups.smart.enabled", false);
user_pref("browser.smartwindow.enabled", false);
user_pref("browser.ai.control.sidebarChatbot", "blocked");
user_pref("browser.ai.control.smartTabGroups", "blocked");
user_pref("browser.ai.control.smartWindow", "blocked");
user_pref("browser.ai.control.pdfjsAltText", "blocked");
user_pref("browser.ai.control.linkPreviewKeyPoints", "blocked");

// ===== telemetry, experiments, crash reports =====

user_pref("datareporting.policy.dataSubmissionEnabled", false);
user_pref("datareporting.healthreport.uploadEnabled", false);
user_pref("datareporting.usage.uploadEnabled", false);
user_pref("toolkit.telemetry.unified", false);
user_pref("toolkit.telemetry.enabled", false);
// any ping that still gets built has nowhere to go
user_pref("toolkit.telemetry.server", "data:,");
user_pref("toolkit.telemetry.archive.enabled", false);
user_pref("toolkit.telemetry.newProfilePing.enabled", false);
user_pref("toolkit.telemetry.shutdownPingSender.enabled", false);
user_pref("toolkit.telemetry.updatePing.enabled", false);
user_pref("toolkit.telemetry.bhrPing.enabled", false);
user_pref("toolkit.telemetry.firstShutdownPing.enabled", false);
user_pref("toolkit.telemetry.coverage.opt-out", true);
user_pref("toolkit.coverage.opt-out", true);
user_pref("toolkit.coverage.endpoint.base", "");
user_pref("browser.newtabpage.activity-stream.feeds.telemetry", false);
user_pref("browser.newtabpage.activity-stream.telemetry", false);
// studies, normandy and nimbus rollouts can change prefs remotely
user_pref("app.shield.optoutstudies.enabled", false);
user_pref("app.normandy.enabled", false);
user_pref("app.normandy.api_url", "");
user_pref("nimbus.rollouts.enabled", false);
user_pref("breakpad.reportURL", "");
user_pref("browser.tabs.crashReporting.sendReport", false);
user_pref("browser.crashReports.unsubmittedCheck.enabled", false);

// ===== privacy =====

// strict can break a site, turn it off per site from the shield icon
user_pref("browser.contentblocking.category", "strict");
user_pref("privacy.fingerprintingProtection", true);
// strips known tracking params from urls
user_pref("privacy.query_stripping.enabled", true);
// sends the global privacy control "do not sell or share" signal
user_pref("privacy.globalprivacycontrol.enabled", true);
user_pref("dom.security.https_only_mode", true);
// show lookalike unicode domains as xn--
user_pref("network.IDN_show_punycode", true);

// ===== sponsored content and nags =====

// firefox suggest only, search engine suggestions stay on
user_pref("browser.urlbar.suggest.quicksuggest.all", false);
user_pref("browser.urlbar.suggest.quicksuggest.sponsored", false);
user_pref("browser.urlbar.suggest.quicksuggest.nonsponsored", false);
user_pref("browser.urlbar.suggest.trending", false);
user_pref("browser.newtabpage.activity-stream.showSponsored", false);
user_pref("browser.newtabpage.activity-stream.showSponsoredTopSites", false);
user_pref("browser.newtabpage.activity-stream.showSponsoredCheckboxes", false);
user_pref("browser.newtabpage.activity-stream.feeds.section.topstories", false);
// extension and feature recommendation popups
user_pref(
  "browser.newtabpage.activity-stream.asrouter.userprefs.cfr.addons",
  false,
);
user_pref(
  "browser.newtabpage.activity-stream.asrouter.userprefs.cfr.features",
  false,
);
user_pref("browser.discovery.enabled", false);
user_pref("browser.preferences.moreFromMozilla", false);

// ===== forms and passwords =====

user_pref("browser.formfill.enable", false);
user_pref("signon.rememberSignons", false);
user_pref("extensions.formautofill.addresses.enabled", false);
user_pref("extensions.formautofill.creditCards.enabled", false);
