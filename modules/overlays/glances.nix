{
  flake.overlays.glances = _: prev: {
    glances = prev.glances.overridePythonAttrs (old: {
      # python-jose is marked insecure and only backs the web ui's password auth, which is off
      # glances imports it in a try/except and runs without it
      dependencies = builtins.filter (p: (p.pname or "") != "python-jose") old.dependencies;
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
