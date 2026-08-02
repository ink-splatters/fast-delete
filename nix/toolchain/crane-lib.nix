{
  lib,
  inputs,
  ...
}: {
  perSystem = {
    config,
    pkgs,
    ...
  }: {
    options.craneLib = lib.mkOption {
      type = lib.types.attrs;
      default = let
        craneLib = (inputs.crane.mkLib pkgs).overrideToolchain config.rust-toolchain;
      in
        craneLib.overrideScope (_: _: {
          stdenvSelector = _: pkgs.llvmPackages_latest.stdenv;
        });
    };
  };
}
