{
  # launchd agents get no login shell, so each one has to be handed a PATH.
  # derive it once from environment.systemPath instead of pasting a literal into
  # every agent, where it silently drifts when systemPath changes
  flake.modules.darwin.base = { lib, config, ... }: {
    options.launchdUserPath = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      description = "PATH for launchd user agents, derived from environment.systemPath";
    };

    config.launchdUserPath =
      "/Users/eric/.local/bin:"
      +
        builtins.replaceStrings [ "$HOME" "$USER" ] [ "/Users/eric" "eric" ]
          config.environment.systemPath;
  };
}
