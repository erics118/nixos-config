{
  # the hooks in claude/settings.json and codex/hooks.json run rexume by name
  flake.modules.homeManager.darwin = { pkgs, ... }: {
    home.packages = [ pkgs.rexume ];

    # the same bytes rexume embeds, so its daemon never rewrites this link
    home.file.".pi/agent/extensions/rexume.ts".source =
      "${pkgs.rexume.src}/src/runtime/pi/extension.ts";
  };

  # replaces `rexume install`, under the label its docs expect.
  # never run install or uninstall here: install misses the guarded hooks and adds its own through the repo links
  flake.modules.darwin.base =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    {
      launchd.user.agents.rexume.serviceConfig = {
        Label = "io.github.entwining.rexume";
        ProgramArguments = [
          (lib.getExe pkgs.rexume)
          "daemon"
          # the app's own rex, so its api always matches the server the app runs
          "--rex"
          "/Users/eric/Library/Application Support/com.superlogical.rex/RexServer/Versions/Current/Rex Server.app/Contents/MacOS/rex"
          # catppuccin mocha, so restored terminals answer color queries before the app shows them
          "--theme-foreground"
          "#CDD6F4"
          "--theme-background"
          "#1E1E2E"
        ];
        # the daemon finds codex on PATH to send it notices
        EnvironmentVariables.PATH = config.launchdUserPath;
        RunAtLoad = true;
        # restarts the daemon if it crashes
        KeepAlive = true;
        StandardOutPath = "/Users/eric/Library/Logs/rexume.log";
        StandardErrorPath = "/Users/eric/Library/Logs/rexume.log";
      };
    };
}
