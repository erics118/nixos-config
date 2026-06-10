{ inputs, config, ... }: {
  perSystem = { system, ... }: {
    _module.args.pkgs = import inputs.nixpkgs {
      inherit system;
      config.allowUnfree = true;
      overlays = builtins.attrValues config.flake.overlays;
    };
  };
}
