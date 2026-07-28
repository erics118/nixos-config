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
            # rebind ssh escape prefix off ~ so ~n/~p zsh aliases echo instantly
            EscapeChar = "^]";

            forwardAgent = false;
            addKeysToAgent = "no";
            compression = false;
            # exit after ~45s of silence so autossh can notice and reconnect
            serverAliveInterval = 15;
            serverAliveCountMax = 3;
            hashKnownHosts = false;
            userKnownHostsFile = "~/.ssh/known_hosts";
            # reuse one connection per host so repeat commands skip the
            # handshake and the 1password prompt; rtmux opts its autossh out
            controlMaster = "auto";
            controlPath = "~/.ssh/master-%n-%C";
            controlPersist = "10m";
            identitiesOnly = true;
            identityAgent = lib.mkIf isDarwin "\"~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock\"";
          };
        };
      };
    };
}
