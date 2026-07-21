{ inputs, ... }: {
  flake.overlays.smhkd = final: _: {
    smhkd = final.stdenv.mkDerivation {
      pname = "smhkd";
      version = "HEAD";

      src = inputs.smhkd-src;

      nativeBuildInputs = with final; [
        cmake
        ninja
      ];

      cmakeBuildType = "Release";

      # clang-scan-deps can't find libc++ headers through the nix wrapper
      cmakeFlags = [ "-DCMAKE_CXX_SCAN_FOR_MODULES=OFF" ];

      doCheck = true;

      meta = {
        description = "simple modal hotkey daemon";
        homepage = "https://github.com/erics118/smhkd";
        mainProgram = "smhkd";
        platforms = final.lib.platforms.darwin;
      };
    };
  };
}
