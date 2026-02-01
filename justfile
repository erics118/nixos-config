set shell := ["zsh", "-uc"]

# list all commands
[private]
default:
	@just --list

# update all flake inputs
update:
	nix flake update

# garbage collect unused nix store entries
gc:
	nh clean all

# format nix files
fmt:
	find . -type f -name "*.nix" -exec nixfmt {} \;

# switch the NixOS configuration
switch:
	nh os switch

# test the NixOS configuration
test:
	nh os test

# switch home-manager configuration
home:
	nh home switch
