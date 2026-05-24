# nixos-config

Dendritic NixOS/nix-darwin configuration

# Installation

## Prerequisites

- Nix
- [`nh`](https://github.com/viperML/nh) and [`just`](https://github.com/casey/just) (provided via the flake devshell, or install ahead of time)

### Clone

```sh
git clone https://github.com/erics118/nixos-config DIRECTORY
cd DIRECTORY
# link flake to a globally stable location
ln -sfn ~/nixos-config ~/.flake
```

### Build and switch

```sh
just switch   # nh {darwin | os} switch (auto-detected)
```

## Adding a new device

### Bootstrap Nix

- **NixOS**: install with the standard installer, or for a cloud VM use [nixos-infect](https://github.com/elitak/nixos-infect)
- **macOS**: install Nix with ?? (Determinate Nix may not be best anymore)

Enable flakes and nix-command (`experimental-features = nix-command flakes`) if not already enabled:

- Add this to `/etc/nix/nix.conf`:

```nix
experimental-features = flakes nix-command
```

- Then, restart the daemon:
  - Linux: `sudo systemctl nix-daemon`
  - macOS: `sudo launchctl kickstart -k system/org.nixos.nix-daemon`

### Clone the repository

```sh
git clone https://github.com/erics118/nixos-config DIRECTORY
cd DIRECTORY
# link flake to a globally stable location
ln -sfn ~/nixos-config ~/.flake
```

### Define the host

Create `modules/hosts/HOSTNAME.nix`. For examples, see:

- `modules/hosts/orca.nix` - Darwin
- `modules/hosts/squid.nix` - NixOS cloud VM
- `modules/hosts/narwhal.nix` - NixOS dual-booted with Windows with Nvidia GPU

For NixOS, also generate hardware config:

```sh
nixos-generate-config --show-hardware-config > modules/hosts/_hardware/HOSTNAME.nix
```

Then, reference it from the host module's `imports`.

### Set up sops

For NixOS, derive age key from SSH host key. This way, no manual key file is needed.

```sh
nix run nixpkgs#ssh-to-age -- < /etc/ssh/ssh_host_ed25519_key.pub
```

For macOS, or a manual configuration, we store the key in a text file.

```sh
mkdir -p "$HOME/Library/Application Support/sops/age"   # Darwin
# or: mkdir -p ~/.config/sops/age                        # Linux
nix run nixpkgs#age -- keygen -o "AGE_CONFIG_PATH/keys.txt"
```

Then, on an existing machine that can already decrypt the keys:

1. Add the new public key to `.sops.yaml` under `keys:`
   - for host keys, name it `host_HOSTNAME`
   - for manual configuration, name it `eric_HOSTNAME`
2. Then, add it to `key_groups.age`
3. Re-encrypt: `sops updatekeys secrets/secrets.yaml`
4. Commit and push: `git add .sops.yaml secrets/secrets.yaml && git commit -m "add keys for HOSTNAME"`

On the new device, pull and rebuild

### Authenticate cachix (optional)

Go to https://app.cachix.org/personal-auth-tokens and create a new authtoken for this host.
Then, configure cachix to use it

```sh
sudo nix run nixpkgs#cachix authtoken TOKEN
```

Or, remove the `cachix-push` module to skip this step.

### Build and switch

```sh
just switch
```

On NixOS, the first switch may need `sudo nixos-rebuild switch --flake .#HOSTNAME`. After that, `just switch` should work by itself.

### Configuring ssh keys and git

1. On the new device, generate two keys: a default key, and a key for github.com

```sh
ssh-keygen -t ed25519 -C "eric@HOSTNAME" # ~/.ssh/id_ed25519
ssh-keygen -t ed25519 -C "eric@HOSTNAME" # ~/.ssh/id_ed25519_github_erics118
```

2. Add the key to GitHub

```sh
cat ~/.ssh/id_ed25519_github_erics118.pub
```

Go to https://github.com/settings/keys -> New SSH key, and label it HOSTNAME, paste, and save.

Test with `ssh -T git@github.com`

3. Switch the repo remote from HTTPS to SSH

```sh
cd ~/nixos-config
git remote set-url origin git@github.com:erics118/nixos-config.git
```

### Configure various tools

- claude, codex, gemini: configure on first usage
- tailscale: `sudo tailscale login`
