# shellcheck shell=bash disable=SC2016
# block sudo -n on macOS. it never prompts, so it reports sudo as unavailable even though
# Touch ID would approve a plain sudo. elsewhere sudo -n is the right non-hanging check

[ "$(uname)" = Darwin ] || exit 0

# walk sudo's options up to the command it runs. -u, -g, -p, and the like take a value as the next word
hook_any '
  def probe: if length == 0 then false else .[0] as $w |
    if $w == "--non-interactive" then true
    elif $w | startswith("--") then .[1:] | probe
    elif $w | test("^-[ugpCDhRTU]$") then .[2:] | probe
    elif $w | test("^-.*n") then true
    elif $w | startswith("-") then .[1:] | probe
    else false end end;
  tool == "sudo" and (.argv[1:] | probe)
' &&
  hook_deny 'sudo -n never prompts, so it gives a false negative. Run plain sudo and let Touch ID prompt.'

exit 0
