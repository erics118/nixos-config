# Hosts

Each `<host>.nix` sets `configurations.<nixos|darwin>.<host>.module`, which lists the aspects that host imports (`m.<class>.<name>`). The option is a deferredModule (`providers/nixos.nix`, `providers/darwin.nix`), so other files merge into the same host. `nixos-config-private` has its own `modules/hosts/narwhal.nix` and `orca.nix`, which add more imports. The file here is not the full list.

`_hardware/` holds `nixos-generate-config` and disko output. The `_` prefix keeps import-tree from loading these files, so each host imports its own by path. Their generated header says to edit `/etc/nixos/configuration.nix`. That file does not exist here, so edit the host module instead.
