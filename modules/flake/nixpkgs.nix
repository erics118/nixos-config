{ inputs, ... }:
let
  overlays = import ../../overlays { inherit inputs; };
  overlaysList = builtins.attrValues overlays;
in
{
  perSystem =
    { system, ... }:
    {
      _module.args.pkgs = import inputs.nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = overlaysList;
      };
    };

  flake.overlays = overlays;
}
