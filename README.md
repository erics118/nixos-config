# nixos-config

Dendritic NixOS/nix-darwin configuration

See [SETUP.md](./SETUP.md) for setup instructions

## Architecture

Most of the config is located in this repo, but sensitive information, like secrets, host-specific ssh configs, etc, are stored in [nixos-config-private](https://github.com/erics118/nixos-config-private) (pulled over ssh).

[Dendritic](https://github.com/mightyiam/dendritic): every file under `modules/`
is `import-tree`'d into one [flake-parts](https://flake.parts) evaluation, so all
modules merge into a single option set (the private repo merges into the same
eval).

## Hosts

- `orca` - macbook (apple silicon)
- `narwhal` - desktop pc (with nvidia gpu)
- `turtle` - cloud vm (aarch64)

## Commands

- `just switch`: builds the system and activates it
- `just build`: builds the system without activating
- `just gc`: manually trigger garbage collector
