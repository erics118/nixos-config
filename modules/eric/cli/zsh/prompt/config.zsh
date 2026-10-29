# the look of the zsh prompt and the claude and pi statuslines (ai/claude/statusline.zsh).
# segments are the _pseg_<name> functions in segments.zsh and statusline.zsh

# segments in order. one that has nothing to show is left out
typeset -ga prompt_line1=(dir host git direnv nix duration status)
typeset -ga prompt_line2=(os char)
typeset -ga statusline=(dir host git worktree pr model lines usage)
typeset -ga statusline_pi=(dir host git model usage cost)

# catppuccin mocha, then the terminal's own ansi colors by number, which its theme draws
typeset -gA prompt_palette=(
  teal '#94e2d5' pink '#f5c2e7' yellow '#f9e2af' red '#f38ba8' green '#a6e3a1'
  blue '#89b4fa' mauve '#cba6f7' sky '#89dceb' surface1 '#45475a' surface2 '#585b70'
  dim '#999999'
  bright-yellow 11
)

# palette names. a segment with none uses the terminal's text color
typeset -gA prompt_color=(
  dir teal lock red host yellow git pink nix blue shlvl mauve duration yellow
  status red os green char teal char_error red separator surface1 continuation surface2
  worktree mauve pr sky model blue added green removed red label dim cost dim
  usage_low green usage_mid yellow usage_high red
)

# segments drawn bold. bold needs TERM, so none of the statusline's
typeset -ga prompt_bold=(direnv)

# unicode codepoints, drawn before the segment's text with a space.
# all are one cell wide in hack nerd font
typeset -gA prompt_icon=(
  lock 0xf033e git 0xf062c direnv_base 0xf107f direnv_allowed 0xf42e direnv_notallowed 0xf420 direnv_denied 0xf467 nix_base 0xf1105
  duration 0xf06ad status 0xf0156 arrow 0x25b6 ellipsis 0x2026
  macos 0xf0035 linux 0xf31a nixos 0xf313 ubuntu 0xf31b arch 0xf31e debian 0xf306 fedora 0xf30a
)

# git status marks, in the order they are drawn
typeset -ga prompt_git_marks=(conflicted stashed deleted modified staged untracked)
typeset -gA prompt_git_symbol=(
  conflicted '!' stashed '$' deleted '×' modified '~' staged '+' untracked '?'
  ahead '↑' behind '↓' diverged '↕'
)

typeset -g prompt_separator='├┤'
typeset -g prompt_line1_start='┌┤'
typeset -g prompt_line2_start='└┤'
typeset -g prompt_continuation='∙'

# the folder shows at most this many trailing parts
typeset -gi prompt_dir_parts=5
