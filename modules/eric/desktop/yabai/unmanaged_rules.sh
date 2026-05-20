#!/usr/bin/env bash

# window only
titles=("Window" "Software Updater?")
title_regex=$(printf '%s|' "${titles[@]}" | sed 's/|$//')

yabai -m rule --add label="misc unmanaged windows" title="^($title_regex)$" manage=off

# apps only
apps=(
  "AdGuard for Safari" "AdGuard VPN" "AltTab" "Authy Desktop"
  "Background Music" "Bartender.*" "BetterDiscord" "Box"
  "CleanShot.*" "Desk View" "Dropbox Dash" "Dropover" "Dropshare.*"
  "Espanso" "Find Any File" "Finder" "FiveNotes" "Flow" "Google Drive"
  "GPG Keychain" "Grammarly Desktop" "Hammerspoon" "HazeOver" "Hidden Bar"
  "Hyperduck" "Installer" "JetBrains Toolbox" "Karabiner-MultitouchExtension"
  "MacGPT" "Main" "MediaMate" "Menuwhere" "Microsoft Remote Desktop"
  "NepTunes" "NoteApp" "OmniDiskSweeper" "OnyX" "Photo Booth"
  "Plain Text Editor" "Print Center" "Python" "Rectangle.*" "SideNotes"
  "Silicio" "Siri" "Smooze.*" "Stickies" "System .*" "Tailscale" "Tot"
  "Velja" "Raycast" "Mac Mouse Fix" "Linear Mouse" "Archive Utility"
  "Actions" "Koofr" "Antinote" "FaceTime" "Alcove" "java" "CLion"
  "Parallels Desktop" "particle" "ocaml-voxel"
)
app_regex=$(printf '%s|' "${apps[@]}" | sed 's/|$//')

yabai -m rule --add label="unmanaged apps" app="^($app_regex)$" manage=off

# specific app windows
yabai -m rule --add label="safari prefs" app="^Safari( Technology Preview)?$" title="^(General|Tabs|AutoFill|Passwords|Search|Security|Privacy|Websites|Extensions|Advanced|Developer|Feature Flags|Privacy Report)$" manage=off
yabai -m rule --add label="orion prefs" app="^Orion.*$" title="^(General|Appearance|Tabs|Browsing|Sync|Passwords|Privacy|Search|Websites|Advanced|Edit Bookmark|Plus)$" manage=off
yabai -m rule --add label="arc prefs" app="^Arc$" title="^(Eric|General|Profiles|Max|Shortcuts|Links|Icon|Advanced)$" manage=off
yabai -m rule --add label="calendar prefs" app="^Calendar$" title="^(General|Accounts|Alerts|Advanced)$" manage=off
yabai -m rule --add label="craft prefs" app="^Craft$" title="^Settings$" manage=off
yabai -m rule --add label="orbstack prefs" app="^OrbStack$" title="^(General|System|Docker|Kubernetes|Network|Storage)$" manage=off
yabai -m rule --add label="weather prefs" app="^Weather$" title="^Settings$" manage=off
yabai -m rule --add label="discord updater" app="^Discord.*$" title="^Discord Updater$" manage=off
yabai -m rule --add label="fantastical" app="^Fantastical$" title="^(Flexibits Account|General|Appearance|Events & Tasks|Alerts|Accounts|Calendars & Lists|Openings|Weather|Advanced)$" manage=off
# yabai -m rule --add label="intellij idea" app="^IntelliJ IDEA$" title="^(Move|Delete|Rename|Keyboard Shortcut|Update Project|Add File to Git|Copy)$" manage=off

# intellij
intellij_apps=(
  "IntelliJ IDEA" "PyCharm" "WebStorm" "PhpStorm" "CLion" "Rider" "GoLand" "RubyMine"
)
intellij_app_regex=$(printf '%s|' "${intellij_apps[@]}" | sed 's/|$//')

# only manage the main editor window, which has the dash in the title
yabai -m rule --add label="intellij idea1" app="^($intellij_app_regex)$" title=".*" manage=off
yabai -m rule --add label="intellij idea" app="^($intellij_app_regex)$" title=".* –.*" manage=on

# orion popups
yabai -m rule --add label="orion popup 1" app="^Orion.*$" role="^(AXPopover|Orion Preview.*|Bitwarden)$" manage=off

# zoom
yabai -m rule --add label="unmanage zoom" app="^zoom\\.us$" manage=off
yabai -m rule --add label="manage zoom main window" title="^Zoom Meeting.*$" app="^zoom\\.us$" subrole="^AXStandardWindow$" manage=on

# apple music mini player
yabai -m rule --add label="apple music" app="^Music$" title="^MiniPlayer$" manage=off

# firefox pip
yabai -m rule --add label="firefox pip" app="^Firefox$" title="^Picture-in-Picture$" manage=off

# dev apps
yabai -m rule --add label="dev apps" app="^knot$" manage=off

# wezterm scratchpad
# yabai -m rule --add label="terminal scratchpad" app="WezTerm" manage=off

yabai -m rule --apply

printf 'loaded unmanage rules..\n'
