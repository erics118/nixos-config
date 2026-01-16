set shell := ["zsh", "-uc"]

# list all commands
default:
	@just --list

# update all flake inputs
update:
	nix flake update

# garbage collect unused nix store entries
gc:
	sudo nix-collect-garbage --delete-older-than 7d
	nix-collect-garbage --delete-older-than 7d

# format nix files
fmt:
	find . -type f -name "*.nix" -exec nixfmt {} \;

# switch the nixos confiuration
switch:
	sudo nixos-rebuild switch
