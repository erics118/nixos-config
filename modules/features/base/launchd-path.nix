{
  # launchd agents get no login shell, so each one has to be handed a PATH.
  # defined once here so the agents that share it cannot drift apart
  flake.modules.darwin.base = { lib, ... }: {
    options.launchdUserPath = lib.mkOption {
      type = lib.types.str;
      default = "/Users/eric/.local/bin:/Users/eric/.nix-profile/bin:/etc/profiles/per-user/eric/bin:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin";
      description = "PATH for launchd user agents";
    };
  };
}
