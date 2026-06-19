{
  flake.modules.homeManager.base =
    { pkgs, lib, ... }:

    let
      inherit (pkgs.stdenv.hostPlatform) isDarwin;
      mkGit =
        hostname: filename:
        {
          inherit hostname;
          user = "git";
          identitiesOnly = true;
        }
        // lib.optionalAttrs (!isDarwin) { identityFile = "~/.ssh/${filename}"; };

    in
    {
      programs.ssh = {
        enable = true;
        enableDefaultConfig = false;

        includes = [
          "~/.ssh/config.local"
        ]
        ++ lib.optionals isDarwin [
          "~/.orbstack/ssh/config"
          "~/.ssh/1Password/config"
        ];

        settings = {
          "github.com" = mkGit "github.com" "id_ed25519_github_erics118";

          "github.coecis.cornell.edu" = mkGit "github.coecis.cornell.edu" "id_ed25519_cornell";

          "*" = {
            forwardAgent = false;
            addKeysToAgent = "no";
            compression = false;
            serverAliveInterval = 0;
            serverAliveCountMax = 3;
            hashKnownHosts = false;
            userKnownHostsFile = "~/.ssh/known_hosts";
            controlMaster = "no";
            controlPath = "~/.ssh/master-%n-%C";
            controlPersist = "no";
            identityAgent = lib.mkIf isDarwin "\"~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock\"";
          };
        };
      };
    };
}
