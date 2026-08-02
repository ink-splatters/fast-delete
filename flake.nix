{
  inputs = {
    advisory-db = {
      flake = false;
      url = "github:rustsec/advisory-db";
    };
    crane.url = "github:ipetkov/crane";
    fenix = {
      url = "github:nix-community/fenix/monthly";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.rust-analyzer-src.follows = "";
    };
    import-tree.url = "github:vic/import-tree";

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    systems.url = "github:ink-splatters/nix-systems"; # no x86_64-darwin
  };

  nixConfig = {
    extra-substituters = [
      "https://nix-community.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  outputs = inputs @ {flake-parts, ...}:
    flake-parts.lib.mkFlake {inherit inputs;} ({lib, ...}: let
      importTree = inputs.import-tree;
      systems = import inputs.systems;
      flakeModules.default = import ./nix {inherit importTree;};
    in {
      imports = [
        flakeModules.default
        flake-parts.flakeModules.partitions
      ];

      options = {
        src = lib.mkOption {
          type = lib.types.path;
          default = builtins.path {
            path = ./.;
            name = "fast-delete";
          };
        };
      };
      config = {
        inherit systems;

        partitionedAttrs = {
          apps = "dev";
          checks = "dev";
          devShells = "dev";
          formatter = "dev";
        };
        partitions.dev = let
          dev = import ./nix/dev {inherit importTree;};
        in {
          extraInputsFlake = ./nix/dev;
          module.imports = [dev];
        };

        perSystem = {config, ...}: {
          packages.default = config.packages.fast-delete;
        };

        flake = {inherit flakeModules;};
      };
    });
}
