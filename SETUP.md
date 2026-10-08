# Setup

## Install Nix

- desktop: use the standard graphical installer
- cloud vm: see later
- macOS: use the official installer from nixos.org. nix-darwin manages nix here, and it aborts activation when Determinate Nix is installed

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

Add `id_ed25519_github_erics118` to GitHub at <https://github.com/settings/keys>.

Explicitly set the git cloning command with:

```sh
export GIT_SSH_COMMAND="ssh -i ~/.ssh/id_ed25519_github_erics118 -o IdentitiesOnly=yes"
```

## Clone the repository

```sh
git clone git@github.com:erics118/nixos-config DIRECTORY
# link flake to a globally stable location
ln -sfn "$(realpath DIRECTORY)" ~/.flake
```

The `~/.flake` link is required. Linked config files point through it, and home-manager activation aborts if `~/.flake/flake.nix` does not resolve. NixOS auto-upgrade also builds from `/home/eric/.flake`.

## Define the host

Create `modules/hosts/HOSTNAME.nix`. Make sure to `git add`.

For macOS:

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

For NixOS, also generate hardware config:

```sh
nixos-generate-config --show-hardware-config > modules/hosts/_hardware/ARCH-HOSTNAME.nix
```

Then, reference it from the host module's `imports`.

## Set up sops

`.sops.yaml` in the private repo ([nixos-config-private](https://github.com/erics118/nixos-config-private)) has two kinds of recipients:

- `host_HOSTNAME`: age key derived using `ssh-to-age` on the host's public ed25519 ssh key. Used by sops-nix to decrypt on activation.
- `eric_HOSTNAME`: raw ssh-ed25519 key used to interactively edit secrets from that machine.

On the new device, get the existing age key:

```sh
nix run nixpkgs#ssh-to-age -- < /etc/ssh/ssh_host_ed25519_key.pub
```

On an existing machine, in the private repo:

- Add `&host_HOSTNAME age1...` with the age key that you just derived
- Add `&eric_HOSTNAME ssh-ed25519 ...` with the contents of `~/.ssh/id_ed25519.pub`
- Reference the anchors in `key_groups`
- Run `sops updatekeys secrets/secrets.yaml`
- Commit and push: `git add .sops.yaml secrets/secrets.yaml && git commit -m "add keys for HOSTNAME" && git push`

On the new device, bump the private pinned input and build:

```sh
nix flake update nixos-config-private
# first build. `just switch` works after that
sudo nixos-rebuild switch --flake .#HOSTNAME # NixOS
sudo nix run nix-darwin -- switch --flake .#HOSTNAME # macOS
```

---

## Cloud VMs

We use [nixos-anywhere](https://github.com/nix-community/nixos-anywhere) to install NixOS on an existing cloud VM.

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

Run nixos-anywhere from an existing nix machine: (`KEY` = the existing ssh key for the target machine)

```sh
nix run github:nix-community/nixos-anywhere -- \
  --generate-hardware-config nixos-generate-config ./modules/hosts/_hardware/ARCH-HOSTNAME.nix \
  --flake .#HOSTNAME \
  --build-on-remote \
  --target-host USERNAME@HOST \
  -i ~/.ssh/KEY --ssh-option IdentitiesOnly=yes
```

`HOST` is the VM's address (IP or DNS), not the nix hostname. Run
`ssh-keygen -R HOST` to refresh the host key, as it has changed.

Make sure to `git add` and `git commit` the generated hardware file.

Now, ssh into the new machine and follow [GitHub SSH Access](#github-ssh-access), [Clone the repository](#clone-the-repository), and [Set up sops](#set-up-sops).

---

## Post setup

- AdGuard Home: set up `eric` admin account via the wizard on port 3000. blocklists are declarative, but login and other configs are not
- Tailscale: run `sudo tailscale up --advertise-exit-node` the first time manually, and authenticate. Also, from admin console, you have to manually approve the exit node
- `gh` cli: `gh auth login`
- install `claude`, `codex`, and `pi` by using their own installers so they are auto-updated faster than it would be via nix
- auto-upgrade hosts (those importing `m.nixos.auto-upgrade`): root needs `/root/.ssh/id_deploy`, with its `.pub` added as a read-only deploy key on nixos-config-private. Upgrades refuse a checkout that is off `main`, dirty, or ahead of `origin/main`, so a local `flake.lock` bump blocks them. See `modules/features/system/auto-upgrade.nix`
