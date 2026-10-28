{ inputs, ... }: {
  # the rex app runs the mac's server, so the mac takes only the cli, its ~/.terminfo entry, and its ssh guard.
  # config stays unset, since init.lua is linked live below
  flake.modules.homeManager.darwin = {
    imports = [ inputs.rex.homeModules.default ];
    programs.rex.enable = true;
  };

  # cmd-a is the app's edit > select all menu item, not a rex shortcut that init.lua can unbind.
  # it moves to cmd-ctrl-opt-shift-f20 (appkit's \uf717), which no mac keyboard has.
  # nix strings can't hold the \0 that usually clears a menu key
  flake.modules.darwin.base.system.defaults.CustomUserPreferences."com.superlogical.rex".NSUserKeyEquivalents."Select All" =
    builtins.fromJSON ''"@^~$\uf717"'';

  flake.modules.homeManager.base =
    {
      config,
      pkgs,
      repoFile,
      ...
    }:
    {
      # files are linked one by one, since rex writes its own such as terminfo-hosts into ~/.config/rex.
      # rex/catppuccin-mocha.conf is not linked: the app keeps its own copy, imported with Import Theme File
      home.file.".config/rex/init.lua".source = repoFile "modules/eric/cli/rex/init.lua";

      # rex requires modules from beside the init.lua link
      home.file.".config/rex/rex-image-paste".source = inputs.rex-image-paste-src;

      # rex itself comes from PATH, so a rex terminal uses the rex matching its server
      home.packages = [
        (pkgs.writeShellApplication {
          name = "rext";
          runtimeInputs = [
            config.programs.sesh.package
            pkgs.fzf
            pkgs.git
            pkgs.jq
          ];
          text = builtins.readFile ./rex/rext.sh;
        })
      ];
    };
}
