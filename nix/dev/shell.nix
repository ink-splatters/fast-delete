{
  perSystem = {
    config,
    inputs',
    ...
  }: let
    inherit (config) pre-commit craneLib;
    inherit (inputs'.fenix.packages.complete) rust-analyzer rust-src;
  in {
    devShells.default = craneLib.devShell ({
        packages =
          pre-commit.settings.enabledPackages
          ++ [
            # pkgs.zizmor
            rust-analyzer
            rust-src
          ];

        shellHook = ''
          export RUST_SRC_PATH="${rust-src}/lib/rustlib/src/rust/library"
          ${pre-commit.installationScript}
        '';
      }
      // (builtins.removeAttrs config.commonArgsNative ["src"]));
  };
}
