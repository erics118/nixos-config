{
  flake.modules.homeManager.base =
    { pkgs, lib, ... }:

    let
      inherit (pkgs.stdenv.hostPlatform) isDarwin;
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
          "github.com" = {
            hostname = "github.com";
            user = "git";
            identityFile = "~/.ssh/id_ed25519_github_erics118";
            identitiesOnly = true;
          };

          "github.coecis.cornell.edu" = {
            hostname = "github.coecis.cornell.edu";
            user = "git";
            identityFile = "~/.ssh/id_ed25519_cornell";
            identitiesOnly = true;
          };

          "*" = {
            forwardAgent = false;
            addKeysToAgent = "no";
            compression = false;
            serverAliveInterval = 0;
            serverAliveCountMax = 3;
            hashKnownHosts = false;
            userKnownHostsFile = "~/.ssh/known_hosts";
            controlMaster = "no";
            controlPath = "~/.ssh/master-%r@%n:%p";
            controlPersist = "no";
            identityAgent = lib.mkIf isDarwin "\"~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock\"";
          };
        };
      };
    };
}
