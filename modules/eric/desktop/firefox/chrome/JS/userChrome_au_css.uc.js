// ==UserScript==
// @name           userChrome_author_css
// @namespace      userChrome_Author_Sheet_CSS
// @version        0.0.7
// @description    Load userChrome.au.css file as author sheet from resources folder using chrome: uri. Runs per window: the upstream @onlyonce + Windows.onCreated pairing only ever reached the first window.
// ==/UserScript==

(function () {
  // Store and preload the author style sheet
  const sss = Cc["@mozilla.org/content/style-sheet-service;1"].getService(
    Ci.nsIStyleSheetService,
  );
  const sheet = sss.preloadSheet(
    makeURI("chrome://userChrome/content/userChrome.au.css"),
    sss.AUTHOR_SHEET,
  );
  // Inject the preloaded style sheet to this window
  try {
    window.windowUtils.addSheet(sheet, Ci.nsIDOMWindowUtils.AUTHOR_SHEET);
  } catch (e) {
    console.error(`Could not pre-load userChrome.au.css: ${e.name}`);
  }
})();
