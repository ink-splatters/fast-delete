{lib, ...}: {
  perSystem = {
    inputs',
    pkgs,
    ...
  }: let
    fenixDefault = inputs'.fenix.packages.default;
    rustTarget = pkgs.stdenv.hostPlatform.rust.rustcTarget;

    darwinRustc = fenixDefault.rustc-unwrapped.overrideAttrs (old: {
      postFixup =
        (old.postFixup or "")
        + ''
          # Fenix Darwin rust-objcopy can miss its bundled libLLVM rpath.
          # https://github.com/nix-community/fenix/issues/242
          install_name_tool -add_rpath "$out/lib" "$out/lib/rustlib/${rustTarget}/bin/rust-objcopy"
        '';
    });

    darwinToolchain = fenixDefault.toolchain.overrideAttrs (_old: {
      paths = [
        fenixDefault.cargo
        fenixDefault.clippy-preview-unwrapped
        fenixDefault.rust-docs
        fenixDefault.rust-std
        darwinRustc
        fenixDefault.rustfmt-preview
      ];
    });
  in {
    options.rust-toolchain = lib.mkOption {
      type = lib.types.attrs;
      default =
        if pkgs.stdenv.hostPlatform.isDarwin
        then darwinToolchain
        else fenixDefault.toolchain;
    };
  };
}
