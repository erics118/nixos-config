{
  flake.overlays.smhkd = final: _: {
    smhkd = final.stdenv.mkDerivation {
      pname = "smhkd";
      version = "HEAD";

      src = final.fetchFromGitHub {
        owner = "erics118";
        repo = "smhkd";
        rev = "01c41b8961616aa68f088873ba82ee4002bf50eb";
        hash = "sha256-xjvGsYqiKGrLbhqGLvky3GlLBW91vsp5aJmVokpV/TA=";
      };

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
