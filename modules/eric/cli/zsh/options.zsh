setopt auto_menu
setopt complete_in_word
setopt always_to_end
setopt auto_pushd
setopt pushd_ignore_dups
setopt pushdminus
setopt autocd
setopt interactive_comments
setopt no_beep
setopt no_flow_control

hash -d n="$HOME/nixos-config"
hash -d p="$HOME/nixos-config-private"
hash -d d="$HOME/dev"

# don't highlight path separators
typeset -gA ZSH_HIGHLIGHT_STYLES
ZSH_HIGHLIGHT_STYLES[path]="fg=none"
ZSH_HIGHLIGHT_STYLES[path_prefix]="fg=none"
ZSH_HIGHLIGHT_STYLES[path_pathseparator]="none"
ZSH_HIGHLIGHT_STYLES[path_prefix_pathseparator]="none"
ZSH_HIGHLIGHT_STYLES[autodirectory]="fg=none"
ZSH_HIGHLIGHT_STYLES[autodirectory_prefix]="fg=none"
