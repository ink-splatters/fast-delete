{lib, ...}: {
  perSystem = {
    config,
    pkgs,
    ...
  }: let
    inherit (config) fenix;
    inherit
      (fenix.packages.complete)
      cargo
      rustfmt
      rust-std
      clippy-unwrapped
      rustc-unwrapped
      ;

    inherit (pkgs.stdenv) hostPlatform;

    rustc-unwrapped' = rustc-unwrapped.overrideAttrs (prev: {
      postFixup =
        (prev.postFixup or "")
        + lib.optionalString hostPlatform.isDarwin ''
          # Fenix Darwin rust-objcopy can miss its bundled libLLVM rpath.
          # https://github.com/nix-community/fenix/issues/242
          install_name_tool -add_rpath "$out/lib" "$out/lib/rustlib/${hostPlatform.rust.rustcTarget}/bin/rust-objcopy"
        '';
    });
  in {
    options.rust-toolchain = lib.mkOption {
      type = lib.types.attrs;
      default = fenix.util.combine [
        cargo
        clippy-unwrapped
        rust-std
        rustc-unwrapped'
        rustfmt
      ];
    };
  };
}
