{
  flake.modules.homeManager.base =
    {
      config,
      lib,
      pkgs,
      ...
    }:

    lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
      sops = {
        age.keyFile = "${config.home.homeDirectory}/Library/Application Support/sops/age/keys.txt";
        defaultSopsFile = ../../secrets/secrets.yaml;
        secrets."api/nia" = { };
      };
    };
}
