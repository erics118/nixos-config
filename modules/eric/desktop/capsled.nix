{
  flake.modules.homeManager.darwin = { pkgs, ... }: {
    home.packages = [
      (pkgs.runCommandCC "capsled" { meta.mainProgram = "capsled"; } ''
        mkdir -p $out/bin
        $CC -O2 -Wall -o $out/bin/capsled ${./capsled/capsled.c} -framework IOKit -framework CoreFoundation
      '')
    ];
  };
}
