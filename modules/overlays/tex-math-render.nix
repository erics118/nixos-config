{
  # draws LaTeX as terminal-cell PNGs for the tex-math claude mod, built from its render/ folder
  flake.overlays.tex-math-render = final: _: {
    tex-math-render = final.buildNpmPackage {
      pname = "tex-math-render";
      version = "0.1.0";
      src = ../eric/ai/claude/mods/tex-math/render;
      npmDepsHash = "sha256-D1wWQjvLq+VsRacRMTDI6HzHm46SpfpmisZugb8owJY=";
      dontNpmBuild = true;
      nativeBuildInputs = [ final.makeWrapper ];
      postInstall = ''
        wrapProgram $out/bin/tex-math-render --prefix PATH : ${final.lib.makeBinPath [ final.resvg ]}
      '';
      meta.mainProgram = "tex-math-render";
    };
  };
  perSystem = { pkgs, ... }: { packages.tex-math-render = pkgs.tex-math-render; };
}
