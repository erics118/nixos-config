{
  flake.modules.homeManager.base = { pkgs, ... }: {
    home.packages = [
      (pkgs.writeShellApplication {
        name = "ask";
        runtimeInputs = with pkgs; [
          curl
          jq
          bc
          coreutils
        ];
        text = builtins.readFile ./ask/ask.sh;
      })
    ];
  };
}
