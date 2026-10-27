# sourced by the .zshrc home-manager builds (see cli/zsh.nix), which also sources prompt/prompt.zsh.
# this folder is linked whole as ~/.config/zsh/conf, so a new file here is live once listed below
for _zsh_conf in options completion functions keys terminal; do
  source ${0:h}/$_zsh_conf.zsh
done
unset _zsh_conf
