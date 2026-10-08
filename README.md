# nixos-config

Dendritic NixOS/nix-darwin configuration

See [SETUP.md](./SETUP.md) for setup instructions

## Architecture

Most of the config is located in this repo, but sensitive information, like secrets, host-specific ssh configs, etc, are stored in [nixos-config-private](https://github.com/erics118/nixos-config-private) (pulled over ssh).

[Dendritic](https://github.com/mightyiam/dendritic): every file under `modules/`
is `import-tree`'d into one [flake-parts](https://flake.parts) evaluation, so all
modules merge into a single option set (the private repo merges into the same
eval).

Each file adds to one or more aspects, `flake.modules.<nixos|darwin|homeManager>.<name>`.
Many files add to the same `base` aspect, and `features/base/hm.nix` gives
`homeManager.base` to user `eric` on both platforms. A host in `modules/hosts/`
picks aspects with `m.<class>.<name>`. Some aspects, such as `sops`, `sops-homelab`,
and the media stack, are defined in the private repo. import-tree skips any path
that starts with `_`.

Files linked with `repoFile` or `repoFileAll` point through `~/.flake` into this checkout. See [AGENTS.md](./AGENTS.md) for the link chain and what needs `just switch`.

## Hosts

- `orca` - macbook (apple silicon)
- `narwhal` - desktop pc (with nvidia gpu)
- `turtle` - cloud vm (aarch64)

## Commands

Run `just` for every recipe.

- `just switch`: builds the system and activates it
- `just build`: builds the system without activating
- `just dev`: switches using a sibling checkout at `../nixos-config-private` instead of the pinned private input
- `just check`: runs `nix flake check`
- `just gc`: manually trigger garbage collector

CI (`.github/workflows/check.yml`) runs `nix flake check` (checks in `modules/checks.nix` and `modules/tests.nix`) on each platform, plus a separate `ai-agent-tests` job for the agent hook and pi extension tests.
