{
  flake.modules.homeManager.base =
    { config, lib, ... }:
    let
      cfg = config.programs.zsh-abbr-lite;

      mkEntries = lib.mapAttrsToList (k: v: "  [${k}]=${lib.escapeShellArg v}");
      abbrEntries = lib.concatStringsSep "\n" (mkEntries cfg.abbreviations);
      globalAbbrEntries = lib.concatStringsSep "\n" (mkEntries cfg.globalAbbreviations);
    in
    {
      options.programs.zsh-abbr-lite = {
        enable = lib.mkEnableOption "lightweight zsh abbreviation expansion";

        abbreviations = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = { };
          description = ''
            Abbreviations that expand only at command position (start of a command, or after a separator like ;, |, &, ()
          '';
          example = {
            g = "git";
            gst = "git status";
          };
        };

        globalAbbreviations = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = { };
          description = ''
            Abbreviations that expand anywhere on the command line, regardless of position
          '';
          example = {
            JQ = "| jq";
            "..." = "../..";
          };
        };
      };

      config = lib.mkIf cfg.enable {
        programs.zsh.initContent = lib.mkAfter ''
          typeset -A _ZSH_ABBR_LITE_CMD=(
            ${abbrEntries}
          )

          typeset -A _ZSH_ABBR_LITE_GLOBAL=(
            ${globalAbbrEntries}
          )

          _zsh-abbr-lite-expand() {
            emulate -L zsh
            local word=''${LBUFFER##* }
            [[ -z $word ]] && return
            if [[ -n ''${_ZSH_ABBR_LITE_GLOBAL[$word]} ]]; then
              LBUFFER="''${LBUFFER%$word}''${_ZSH_ABBR_LITE_GLOBAL[$word]}"
              return
            fi
            if [[ -n ''${_ZSH_ABBR_LITE_CMD[$word]} ]]; then
              # only at command position: prefix empty after whitespace strip,
              # or ends with a command separator.
              local prefix=''${LBUFFER%$word}
              if [[ $prefix =~ '^[[:space:]]*$' || $prefix =~ '[;|&(][[:space:]]*$' ]]; then
                LBUFFER="''${LBUFFER%$word}''${_ZSH_ABBR_LITE_CMD[$word]}"
              fi
            fi
          }

          _zsh-abbr-lite-space()  { _zsh-abbr-lite-expand; zle self-insert }
          _zsh-abbr-lite-accept() { _zsh-abbr-lite-expand; zle accept-line }

          zle -N _zsh-abbr-lite-space
          zle -N _zsh-abbr-lite-accept

          bindkey ' '  _zsh-abbr-lite-space
          bindkey '^M' _zsh-abbr-lite-accept
          bindkey -M isearch ' ' self-insert
        '';
      };
    };
}
