{
  flake.overlays.websockify = _: prev: {
    pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
      (_: pyprev: {
        websockify = pyprev.websockify.overridePythonAttrs (old: {
          # jwcrypto now rejects the short hmac key in these tests' fixture
          disabledTests = (old.disabledTests or [ ]) ++ [
            "test_symmetric_jws_token_plugin"
            "test_symmetric_jws_token_plugin_with_illigal_key_exception"
          ];
        });
      })
    ];
  };
}
