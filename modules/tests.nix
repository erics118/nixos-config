{ config, ... }:
let
  m = config.flake.modules;
in
{
  perSystem =
    {
      lib,
      pkgs,
      system,
      ...
    }:
    {
      # the service modules don't depend on the arch, so only the x86 runner boots them
      checks = lib.optionalAttrs (system == "x86_64-linux") {
        test-ntfy = pkgs.testers.runNixOSTest {
          name = "ntfy";
          nodes.machine = {
            imports = [ m.nixos.ntfy ];
            # stub for an option from nixos.base, which is too heavy to import
            options.ntfyHost = lib.mkOption { default = "ntfy.test"; };
            # the vm has no sops key, so a stub stands in for sops-nix
            options.sops = lib.mkOption { type = lib.types.anything; };
            config = {
              sops.secrets."ntfy/auth-env".path = "/dev/null";
              services.ntfy-sh.environmentFile = lib.mkForce null;
              environment.systemPackages = [ pkgs.curl ];
            };
          };
          # an anonymous publish must stay forbidden, since the server is public
          testScript = ''
            machine.wait_for_unit("ntfy-sh.service")
            machine.wait_for_open_port(2586, "::1")
            machine.succeed("curl -sf 'http://[::1]:2586/v1/health' | grep -q '\"healthy\":true'")
            code = machine.succeed("curl -s -o /dev/null -w '%{http_code}' -d hi 'http://[::1]:2586/test'")
            assert code == "403", f"anonymous publish returned {code}"
          '';
        };
      };
    };
}
