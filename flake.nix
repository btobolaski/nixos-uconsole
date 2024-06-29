{
  description = "NixOS support for clockworkPi uConsole";

  inputs.nixpkgs.url = "nixpkgs/nixos-unstable";
  inputs.nixos-hardware.url = "github:NixOS/nixos-hardware/master";

  outputs = {
    self,
    nixpkgs,
    nixos-hardware,
  }: let
    system = "aarch64-linux";

    overlays = [
      (final: super: {
        makeModulesClosure = x:
          super.makeModulesClosure (x // {allowMissing = true;});
      })
      # (final: super: {zfs = super.zfs.overrideAttrs (_: {meta.platforms = [];});}) # disable zfs
    ];

    pkgs = import nixpkgs {inherit system overlays;};

    base-module = import ./module.nix {inherit nixpkgs;};

    kernels = import ./kernels/default.nix;

    base-system-cm4 = kernel:
      nixpkgs.lib.nixosSystem {
        inherit system pkgs;
        specialArgs = {
          inherit nixpkgs nixos-hardware;
        };

        modules = [base-module kernel];
      };

    images =
      pkgs.lib.attrsets.mapAttrs' (name: value: {
        name = "sd-image-cm4-${name}";
        value = (base-system-cm4 value).config.system.build.sdImage;
      })
      kernels;
  in {
    packages."aarch64-linux" = images;

    nixosConfigurations.uconsole = base-system-cm4 kernels."6.1-potatomania-cross-build";

    nixosModules =
      {default = base-module;}
      // (pkgs.lib.attrsets.mapAttrs' (name: value: {
          name = "kernel-${name}";
          inherit value;
        })
        kernels);
  };
}
