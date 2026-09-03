// ==UserScript==
// @name           userChrome_author_css
// @namespace      userChrome_Author_Sheet_CSS
// @version        0.0.7
// @description    Load userChrome.au.css as an author sheet, once per window.
// ==/UserScript==

(function () {
  const sss = Cc["@mozilla.org/content/style-sheet-service;1"].getService(
    Ci.nsIStyleSheetService,
  );
  const sheet = sss.preloadSheet(
    makeURI("chrome://userChrome/content/userChrome.au.css"),
    sss.AUTHOR_SHEET,
  );
  try {
    window.windowUtils.addSheet(sheet, Ci.nsIDOMWindowUtils.AUTHOR_SHEET);
  } catch (e) {
    console.error(`Could not pre-load userChrome.au.css: ${e.name}`);
  }
})();
