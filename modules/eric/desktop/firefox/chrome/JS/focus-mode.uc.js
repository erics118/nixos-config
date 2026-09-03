// focus-mode.uc.js
// Cmd+Shift+F toggles focus-mode on #main-window; userChrome.css hides the
// toolbox, bookmarks bar, and Sidebery. frees the combo from native fullscreen

(function () {
  document.getElementById("key_enterFullScreen_old")?.remove();

  function toggleFocusMode() {
    const win = document.getElementById("main-window");
    win.toggleAttribute("focus-mode");
  }

  const keyset = document.createXULElement("keyset");
  keyset.id = "focusModeKeyset";
  const key = document.createXULElement("key");
  key.id = "key_focusMode";
  key.setAttribute("key", "F");
  key.setAttribute("modifiers", "accel,shift");
  key.addEventListener("command", toggleFocusMode);
  keyset.appendChild(key);

  // insert as a fresh keyset before mainKeyset so the <key> registers (bug 832984)
  const mainKeyset = document.getElementById("mainKeyset");
  mainKeyset.parentNode.insertBefore(keyset, mainKeyset);
})();
