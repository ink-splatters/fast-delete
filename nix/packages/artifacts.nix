{lib, ...}: {
  perSystem = {config, ...}: let
    inherit (config) craneLib commonArgs commonArgsNative;
  in {
    options = {
      cargoArtifacts = lib.mkOption {
        type = lib.types.package;
        default = craneLib.buildDepsOnly (commonArgs
          // {
            pname = "fast-delete";
            # Include dev dependencies for clippy offline mode
            cargoCheckExtraArgs = "--all-targets --all-features";
          });
      };
      cargoArtifactsNative = lib.mkOption {
        type = lib.types.package;
        default = craneLib.buildDepsOnly (commonArgsNative
          // {
            pname = "fast-delete-native";
          });
      };
    };
  };
}
