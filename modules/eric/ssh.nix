{
  flake.modules.homeManager.base =
    { pkgs, lib, ... }:

    let
      inherit (pkgs.stdenv.hostPlatform) isDarwin;
    in
    {
      # the 1password agent serves the private half
      home.file.".ssh/keys/github_erics118.pub" = lib.mkIf isDarwin {
        text = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO2fRl3E9j8GZxoB3JMJoho4GWM6nY90Ob+bqxASZMrM\n";
      };

      programs.ssh = {
        enable = true;
        enableDefaultConfig = false;

        includes = [ "~/.ssh/config.local" ] ++ lib.optionals isDarwin [ "~/.orbstack/ssh/config" ];

        settings = {
          "github.com" = {
            hostname = "github.com";
            user = "git";
            identitiesOnly = true;
            identityFile =
              if isDarwin then "~/.ssh/keys/github_erics118.pub" else "~/.ssh/id_ed25519_github_erics118";
          };

          # cev tailnet, prefer password authentication
          "*.tail4ccb95.ts.net" = {
            user = "cev";
            PubkeyAuthentication = "no";
            PreferredAuthentications = "keyboard-interactive,password";
          };

          "*" = {
            # rebind ssh escape prefix from ~ to Ctrl-] so zsh named directories work instantly
            EscapeChar = "^]";

            # macOS skips tailscale's search domains for one-word names, so ssh appends them itself
            CanonicalizeHostname = "yes";
            CanonicalDomains = "tail4ccb95.ts.net dolphin-sailfin.ts.net tailda7ea.ts.net";
            CanonicalizeMaxDots = 0;

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
            controlPath = "~/.ssh/master-%C";
            controlPersist = "4h";
            identitiesOnly = true;
            identityAgent = lib.mkIf isDarwin "\"~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock\"";
          };
        };
      };
    };
}
