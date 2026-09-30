{
  # run a command in the cs3410 risc-v container with the current directory mounted
  flake.modules.homeManager.base = { pkgs, ... }: {
    home.packages = [
      (pkgs.writeShellApplication {
        name = "rv";
        text = ''
          exec docker run -i --init --rm -v "$PWD":/root ghcr.io/sampsyo/cs3410-infra "$@"
        '';
      })
    ];
  };
}
