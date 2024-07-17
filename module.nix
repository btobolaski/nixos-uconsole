{nixpkgs, ...}: {
  pkgs,
  lib,
  config,
  ...
}: {
  imports = [
    "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
  ];

  options = {
    uconsole.boot.configTxt = with lib;
      mkOption {
        type = types.string;
      };
    uconsole.boot.kernel.crossBuild = with lib;
      mkOption {
        type = types.bool;
      };
  };

  config = {
    boot.kernelParams = ["console=serial0,115200" "console=tty1"];

    system.stateVersion = "23.11";

    sdImage.compressImage = false;
    sdImage.populateFirmwareCommands = let
      configTxt = pkgs.writeText "config.txt" config.uconsole.boot.configTxt;
    in ''
      # Add the config
      rm -f firmware/config.txt
      cp ${configTxt} firmware/config.txt
    '';
  };
}
