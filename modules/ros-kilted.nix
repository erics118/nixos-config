{ pkgs, inputs, ... }:

let
  nix-ros-overlay = inputs.nix-ros-overlay;

  rosPkgs = import nix-ros-overlay.inputs.nixpkgs {
    system = pkgs.stdenv.hostPlatform.system;
    overlays = [ nix-ros-overlay.overlays.default ];
  };

  ros = rosPkgs.rosPackages.kilted;

  # "Desktop-ish" selection (since ros-desktop attr doesn't exist)
  rosDesktopLike = ros.buildEnv {
    paths = [
      ros.ros-core
      ros.rviz2
      ros.rqt
      ros.rqt-common-plugins
      ros.turtlesim
      ros."demo-nodes-cpp"
      ros."demo-nodes-py"
      ros."joint-state-publisher-gui"
      ros."robot-state-publisher"
      ros."tf2-tools"
    ];
  };
in
{
  environment.systemPackages = [
    rosPkgs.colcon
    rosDesktopLike
  ];

  nix.settings = {
    substituters = [ "https://ros.cachix.org" ];
    trusted-public-keys = [ "ros.cachix.org-1:dSyZxI8geDCJrwgvCOHDoAfOm5sV1wCPjBkKL+38Rvo=" ];
  };

  environment.sessionVariables = {
    ROS_DISTRO = "kilted";
    ROS_VERSION = "2";
  };

  home-manager.extraSpecialArgs = {
    inherit rosPkgs;
    rosEnv = rosDesktopLike;
  };
}
