// copy-url.uc.js
// Cmd+Shift+C copies the current tab's URL to the clipboard. The native
// Cmd+Shift+C (devtools inspector) is stripped by kill-inspector-shortcuts.uc.js.

(function () {
  function copyUrl() {
    const url = gBrowser.selectedBrowser.currentURI.displaySpec;
    Components.classes["@mozilla.org/widget/clipboardhelper;1"]
      .getService(Components.interfaces.nsIClipboardHelper)
      .copyString(url);
  }

  const keyset = document.createXULElement("keyset");
  keyset.id = "copyUrlKeyset";
  const key = document.createXULElement("key");
  key.id = "key_copyUrl";
  key.setAttribute("key", "C");
  key.setAttribute("modifiers", "accel,shift");
  key.addEventListener("command", copyUrl);
  keyset.appendChild(key);

  // insert as a fresh keyset before mainKeyset so the <key> registers (bug 832984)
  const mainKeyset = document.getElementById("mainKeyset");
  mainKeyset.parentNode.insertBefore(keyset, mainKeyset);
})();
