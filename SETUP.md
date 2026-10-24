# Setup

There are two paths:

- macOS: follow this page from [Install Nix](#install-nix) down to [Post setup](#post-setup)
- NixOS desktop or cloud VM, new or reinstalled: jump to [Install with nixos-anywhere](#install-with-nixos-anywhere). It builds the host from another machine, ships its keys and the repo, and ends at [Post setup](#post-setup)

## Install Nix

macOS only. Use the official installer from nixos.org. nix-darwin manages nix here, and it aborts activation when Determinate Nix is installed

Enable flakes and nix-command for the bootstrap shell:

```sh
export NIX_CONFIG='experimental-features = nix-command flakes'
```

Don't edit `/etc/nix/nix.conf`. nix-darwin aborts activation on an `/etc` file it doesn't recognize, and on NixOS it is a read-only store link. After the first switch, `modules/features/base/nix-common.nix` enables both features.

## GitHub SSH Access

```sh
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -C "eric@HOSTNAME"
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_github_erics118 -C "eric@HOSTNAME"
```

Add `id_ed25519_github_erics118` to GitHub at <https://github.com/settings/keys> twice, as an Authentication key and as a Signing key. `modules/eric/git.nix` signs every commit with it.

Explicitly set the git cloning command with:

```sh
export GIT_SSH_COMMAND="ssh -i ~/.ssh/id_ed25519_github_erics118 -o IdentitiesOnly=yes"
```

## Clone the repository

The clone gets what is on GitHub, so push the new host's files and `flake.lock` first.

```sh
git clone git@github.com:erics118/nixos-config ~/nixos-config
git clone git@github.com:erics118/nixos-config-private ~/nixos-config-private
```

Both checkouts must live at exactly these paths. Files linked with `repoFile` and `privateFile` point into them, and home-manager activation aborts if `~/nixos-config/flake.nix` or `~/nixos-config-private/flake.nix` is missing. NixOS auto-upgrade also builds from `/home/eric/nixos-config`. A NixOS host gets both from [5. Ship the repo](#5-ship-the-repo).

## Define the host

macOS only. NixOS hosts are defined in [Install with nixos-anywhere](#install-with-nixos-anywhere).

Create `modules/hosts/HOSTNAME.nix`. Make sure to `git add`.

```nix
{ config, ... }:
let
  m = config.flake.modules;
in
{
  configurations.darwin.HOSTNAME.module = {
    imports = [
      m.darwin.base
      m.darwin.sops # from nixos-config-private
    ];
    nixpkgs.hostPlatform = "aarch64-darwin";

    networking.hostName = "HOSTNAME";

    home-manager.users.eric.imports = [ m.homeManager.darwin ];
  };
}
```

## Set up sops

`.sops.yaml` in the private repo ([nixos-config-private](https://github.com/erics118/nixos-config-private)) has two kinds of recipients:

- `host_HOSTNAME`: age key derived using `ssh-to-age` on the host's public ed25519 ssh key. Used by sops-nix to decrypt on activation.
- `eric_HOSTNAME`: raw ssh-ed25519 key used to interactively edit secrets from that machine.

On a new macOS device, get the existing age key. A NixOS host gets both keys made ahead of time in [3. Make the keys](#3-make-the-keys):

```sh
nix run nixpkgs#ssh-to-age -- < /etc/ssh/ssh_host_ed25519_key.pub
```

On an existing machine, in the private repo:

- Add `&host_HOSTNAME age1...` with the age key that you just derived
- Add `&eric_HOSTNAME ssh-ed25519 ...` with the contents of `~/.ssh/id_ed25519.pub`
- Reference the anchors in `key_groups`
- On a reinstall, replace the host's existing `host_HOSTNAME` and `eric_HOSTNAME` keys instead of adding new ones
- Run `sops updatekeys secrets/secrets.yaml`
- Commit and push: `git add .sops.yaml secrets/secrets.yaml && git commit -m "add keys for HOSTNAME" && git push`

On a new macOS device, bump the private pinned input and build:

```sh
nix flake update nixos-config-private
# first build. `just switch` works after that
sudo nix run nix-darwin -- switch --flake .#HOSTNAME
```

A NixOS host bumps the lock in [4. Register the keys](#4-register-the-keys), before nixos-anywhere builds it.

---

## Install with nixos-anywhere

We use [nixos-anywhere](https://github.com/nix-community/nixos-anywhere) to install NixOS on an existing cloud VM, or on a desktop booted from the installer. Run everything below from an existing nix machine unless it says otherwise.

Reinstalling narwhal? Read [Reinstalling narwhal](#reinstalling-narwhal) first. It changes what to unplug and what to do on the first boot.

### 1. Boot the target

For a desktop, boot the minimal x86_64 ISO from <https://nixos.org/download> (pick the UEFI boot entry) and unplug any disk you want to keep. Then, on its console:

```sh
sudo -i
nmtui # wifi only
mkdir -p ~/.ssh && curl -L https://github.com/erics118.keys > ~/.ssh/authorized_keys
systemctl start sshd # the installer doesn't start it
ip -4 addr
```

Use `root@<that address>` as `USERNAME@HOST` and `id_ed25519_github_erics118` as `KEY` below.

### 2. Define the host

Reinstall: the host files exist. Check that the disko `device` still names the target's disk (`ls -l /dev/disk/by-id/` on the target), and go to step 3.

New host: for a desktop disk, set the disko `device` to its `/dev/disk/by-id/` path. A desktop with a GPU driver and a few kernels wants a `1G` ESP, as `modules/hosts/_hardware/x86_64-narwhal-disko.nix` has.

<details>
<summary>

Add the disko layout to `modules/hosts/_hardware/ARCH-HOSTNAME-disko.nix`. Use `lsblk` to confirm.

</summary>

```nix
{
  disko.devices.disk.main = {
    device = "/dev/sda";
    type = "disk";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          type = "EF00";
          size = "512M";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };
        root = {
          size = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
          };
        };
      };
    };
  };
}
```

</details>

<details>
<summary>

Add the host module to `modules/hosts/HOSTNAME.nix`.

</summary>

```nix
{ inputs, config, ... }:
let
  m = config.flake.modules;
in
{
  configurations.nixos.HOSTNAME.module = {
    imports = [
      m.nixos.base
      m.nixos.ssh-server
      m.nixos.sops # from nixos-config-private
      m.nixos.tailscale
      inputs.disko.nixosModules.disko
      ./_hardware/ARCH-HOSTNAME.nix
      ./_hardware/ARCH-HOSTNAME-disko.nix
    ];
    nixpkgs.hostPlatform = "ARCH";

    networking.hostName = "HOSTNAME";

    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;
  };
}
```

</details>

And, a stub containing `{ }` at `modules/hosts/_hardware/ARCH-HOSTNAME.nix`.

`git add` all three files. `--flake .#HOSTNAME` reads the git tree, which leaves untracked files out.

### 3. Make the keys

Make every key the host needs on this machine, in a temp dir laid out like the target's `/`. nixos-anywhere copies it onto the new system in step 6, so the first boot can decrypt secrets, use git, and run auto-upgrade with nothing generated on the host. The keys have no passphrase because auto-upgrade uses them unattended.

```sh
HOSTNAME=...
extra=$(mktemp -d) # outside the repo, so no private key can be committed
install -d -m 755 "$extra/etc/ssh" "$extra/home"
install -d -m 700 "$extra/home/eric" "$extra/home/eric/.ssh" "$extra/root" "$extra/root/.ssh"
ssh-keygen -q -t ed25519 -N '' -C "root@$HOSTNAME" -f "$extra/etc/ssh/ssh_host_ed25519_key"
ssh-keygen -q -t ed25519 -N '' -C "eric@$HOSTNAME" -f "$extra/home/eric/.ssh/id_ed25519"
ssh-keygen -q -t ed25519 -N '' -C "eric@$HOSTNAME" -f "$extra/home/eric/.ssh/id_ed25519_github_erics118"
ssh-keygen -q -t ed25519 -N '' -C "root@$HOSTNAME-deploy" -f "$extra/root/.ssh/id_deploy"
```

Keep this shell open. Steps 4 to 6 use `$extra` and `$HOSTNAME`.

### 4. Register the keys

sops, in the private repo ([nixos-config-private](https://github.com/erics118/nixos-config-private)). Commit or stash any other edit to `secrets/secrets.yaml` first, since the commit below takes the whole file.

- `host_HOSTNAME` is `nix run nixpkgs#ssh-to-age -- < "$extra/etc/ssh/ssh_host_ed25519_key.pub"`
- `eric_HOSTNAME` is the contents of `"$extra/home/eric/.ssh/id_ed25519.pub"`
- Reinstall: replace the values of the existing `&host_HOSTNAME` and `&eric_HOSTNAME` anchors
- New host: add both anchors under `keys`, and `*host_HOSTNAME` and `*eric_HOSTNAME` under `key_groups`

```sh
sops updatekeys secrets/secrets.yaml
git commit -m "keys for $HOSTNAME" -- .sops.yaml secrets/secrets.yaml
git push
```

Lock, in this repo. Install from a clean checkout whose HEAD is pushed: step 5 ships a clone of GitHub, and a file that only exists locally becomes a dangling home-manager link on the host.

```sh
nix flake update nixos-config-private
git add flake.lock modules/hosts/$HOSTNAME.nix modules/hosts/_hardware/*-$HOSTNAME*.nix
git commit -m "keys for $HOSTNAME"
git push
```

GitHub:

- <https://github.com/settings/keys>: add `"$extra/home/eric/.ssh/id_ed25519_github_erics118.pub"` twice, as an Authentication key and as a Signing key. `modules/eric/git.nix` signs every commit with it. Reinstall: delete the old host's two keys
- Hosts importing `m.nixos.auto-upgrade` only: <https://github.com/erics118/nixos-config-private/settings/keys>: add `"$extra/root/.ssh/id_deploy.pub"` as a read-only deploy key titled `HOSTNAME`. Reinstall: delete the old one

### 5. Ship the repo

Clone after the pushes, so the clone has the new host files and `flake.lock`:

```sh
git clone git@github.com:erics118/nixos-config "$extra/home/eric/nixos-config"
git clone git@github.com:erics118/nixos-config-private "$extra/home/eric/nixos-config-private"
```

The clones may fall behind `origin/main` later. Auto-upgrade fast-forwards both, and only refuses a public checkout that is dirty or ahead.

### 6. Install

(`KEY` = the existing ssh key for the target machine)

```sh
nix run github:nix-community/nixos-anywhere -- \
  --generate-hardware-config nixos-generate-config ./modules/hosts/_hardware/ARCH-$HOSTNAME.nix \
  --flake .#$HOSTNAME \
  --build-on remote \
  --extra-files "$extra" \
  --chown /home/eric 1000:100 \
  --target-host USERNAME@HOST \
  -i ~/.ssh/KEY --ssh-option IdentitiesOnly=yes
```

`--chown` hands eric's files to uid 1000, which `modules/features/base/nixos.nix` pins. nixos-anywhere copies `$extra` as root, and NixOS chowns only the home dir itself.

The installer keeps its nix store in RAM, and nixos-anywhere hands it only the target's `nix.settings.substituters`, not `extra-substituters`. Keep caches in `substituters` (`modules/features/base/nix-common.nix`), or a cache miss on a big package like wezterm builds from source and can run the installer out of memory.

Then:

```sh
rm -rf "$extra" # the keys now live on the host
ssh-keygen -R HOST # the host key changed, so refresh every name you reach it by
ssh-keygen -R "$HOSTNAME.dolphin-sailfin.ts.net"
git status --short modules/hosts/_hardware/
```

If the generated hardware file changed, commit and push it. The host picks it up on its next auto-upgrade or `just switch`.

`HOST` is the target's address (IP or DNS), not the nix hostname.

### 7. First boot

home-manager, sops secrets, git, and auto-upgrade work from the first boot. eric's console password is the plaintext behind the `eric/password` hash in sops. A host that autologins into a desktop, like narwhal, still offers a console on Ctrl+Alt+F2. On wifi, connect with `nmtui`.

Continue with [Post setup](#post-setup).

---

## Post setup

- AdGuard Home: blocklists and the login are declarative (login from nixos-config-private); clients and other UI settings are not
- Tailscale: run `sudo tailscale up --advertise-exit-node` the first time manually, and authenticate. Also, from admin console, you have to manually approve the exit node. On a reinstall, delete the old machine in the admin console first, or the new one registers as `HOSTNAME-1`. On narwhal, then point these at the new tailnet IP (`tailscale ip -4`): the Cloudflare `h` and `*.h` A records for `h.eriz.cc`, and the admin console's DNS nameserver, which makes every tailnet device use its AdGuard
- `gh` cli: `gh auth login`
- install `claude`, `codex`, and `pi` by using their own installers so they are auto-updated faster than it would be via nix
- auto-upgrade hosts (those importing `m.nixos.auto-upgrade`): root's `/root/.ssh/id_deploy` comes from [3. Make the keys](#3-make-the-keys). A host that adds auto-upgrade later makes one with `sudo ssh-keygen -t ed25519 -N '' -C root@HOSTNAME-deploy -f /root/.ssh/id_deploy` and adds its `.pub` as a read-only deploy key on nixos-config-private. Upgrades refuse a checkout that is off `main`, dirty, or ahead of `origin/main`, so a local `flake.lock` bump blocks them. See `modules/features/system/auto-upgrade.nix`

## Reinstalling narwhal

Its data lives on the USB disk at `/mnt/external` and survives a reinstall. Unplug it for the install. Mounting it starts the services that need it, so after the first boot block Immich for this boot before plugging it back in. `systemctl mask --runtime` doesn't work here, since NixOS units in `/etc/systemd/system` outrank its link:

```sh
sudo mkdir -p /run/systemd/system.control
sudo ln -s /dev/null /run/systemd/system.control/immich-server.service
sudo systemctl daemon-reload
```

Then:

- Immich: restore the newest dump in `/mnt/external/immich/backups` while `immich-server` has never started, per <https://docs.immich.app/administration/backup-and-restore>, then `sudo rm /run/systemd/system.control/immich-server.service && sudo systemctl daemon-reload && sudo systemctl start immich-server`
- Time Machine: on the Mac, remove the narwhal disk, delete its keychain entries, and add it back as `smb://eric@narwhal.dolphin-sailfin.ts.net/timemachine` with the `samba/eric` password from sops
- Time Machine restores skip the fixed paths in `sudo defaults read /Library/Preferences/com.apple.TimeMachine SkipPaths` and any folder listed by `mdfind "com_apple_backup_excludeItem = 'com.apple.backupd'"`. Rebuild those (`npm install`, `cargo build`, `direnv reload`)
