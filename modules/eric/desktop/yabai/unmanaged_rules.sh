#!/usr/bin/env bash

join_re() {
  local IFS='|'
  printf '^(%s)$\n' "$*"
}

# window only
titles=("Window" "Software Updater?")
title_regex=$(join_re "${titles[@]}")

yabai -m rule --add label="misc unmanaged windows" title="^($title_regex)$" manage=off

# apps only
apps=(
  "AdGuard Mini" "AdGuard VPN" "AltTab" "Archive Utility" "Alcove"
  "Background Music" "Box"
  "CleanShot X"
  "Desk View" "Dropover" "Dropshare.*"
  "Espanso"
  "Find Any File" "FaceTime"
  "Google Drive"
  "Hammerspoon" "HazeOver"
  "Installer" "iPhone Mirroring"
  "JetBrains Toolbox"
  "Karabiner-MultitouchExtension"
  "LinearMouse"
  "MediaMate" "Menuwhere" "Mac Mouse Fix"
  "OmniDiskSweeper" "OnyX"
  "Photo Booth" "Print Center"
  "Rectangle.*" "Raycast( Beta)?"
  "Siri" "Stickies" "System .*"
  "Tailscale"

  "Microsoft Remote Desktop" "Parallels Desktop" "WorkSpaces"

  "Main" "java" "Python" "knot"
)
app_regex=$(join_re "${apps[@]}")

yabai -m rule --add label="unmanaged apps" app="^($app_regex)$" manage=off

# specific app windows
yabai -m rule --add label="safari prefs" app="^Safari( Technology Preview)?$" title="^(General|Tabs|AutoFill|Passwords|Search|Security|Privacy|Websites|Extensions|Advanced|Developer|Feature Flags|Privacy Report)$" manage=off
yabai -m rule --add label="orion prefs" app="^Orion.*$" title="^(General|Appearance|Tabs|Browsing|Sync|Passwords|Privacy|Search|Websites|Advanced|Edit Bookmark|Plus)$" manage=off
yabai -m rule --add label="calendar prefs" app="^Calendar$" title="^(General|Accounts|Alerts|Advanced)$" manage=off
yabai -m rule --add label="craft prefs" app="^Craft$" title="^Settings$" manage=off
yabai -m rule --add label="orbstack prefs" app="^OrbStack$" title="^(General|System|Docker|Kubernetes|Network|Storage)$" manage=off
yabai -m rule --add label="weather prefs" app="^Weather$" title="^Settings$" manage=off
yabai -m rule --add label="discord updater" app="^Discord.*$" title="^Discord Updater$" manage=off
yabai -m rule --add label="fantastical" app="^Fantastical$" title="^(Flexibits Account|General|Appearance|Events & Tasks|Alerts|Accounts|Calendars & Lists|Openings|Weather|Advanced)$" manage=off

# jetbrains
jetbrains=(
  "IntelliJ IDEA" "PyCharm" "WebStorm" "PhpStorm" "CLion" "Rider" "GoLand" "RubyMine"
)
jetbrains_regex=$(join_re "${jetbrains[@]}")

# only manage the main editor window, which has the dash in the title
yabai -m rule --add label="intellij idea1" app="^($jetbrains_regex)$" manage=off
yabai -m rule --add label="intellij idea" app="^($jetbrains_regex)$" title=".* –.*" manage=on

# orion popups
yabai -m rule --add label="orion popup 1" app="^Orion.*$" role="^AXPopover$" manage=off
yabai -m rule --add label="orion popup 2" app="^Orion.*$" title="^Orion Preview.*" manage=off

# zoom
# yabai -m rule --add label="unmanage zoom" app="^Zoom$" manage=off
# yabai -m rule --add label="manage zoom main window" app="^Zoom$" subrole="^AXStandardWindow$" manage=on

# apple music mini player
yabai -m rule --add label="apple music" app="^Music$" title="^MiniPlayer$" manage=off

# firefox pip
yabai -m rule --add label="firefox pip" app="^Firefox.*$" title="^Picture-in-Picture$" manage=off

# amazon workspaces login window
yabai -m rule --add label="amazon workspaces" app="^Amazon WorkSpaces$" title="^$" manage=off

# wezterm scratchpad
# yabai -m rule --add label="terminal scratchpad" app="WezTerm" manage=off

printf 'loaded unmanage rules..\n'
