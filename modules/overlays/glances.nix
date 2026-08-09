{
  flake.overlays.glances = _: prev: {
    glances = prev.glances.overrideAttrs (old: {
      # test_phys_core_returns_int is broken
      disabledTests = (old.disabledTests or [ ]) ++ [ "test_phys_core_returns_int" ];
      # these spin up a local http server and flakily fail to connect in the sandbox
      disabledTestPaths = (old.disabledTestPaths or [ ]) ++ [
        "tests/test_restful.py"
        "tests/test_browser_restful.py"
        "tests/test_xmlrpc.py"
      ];
    });
  };
}
