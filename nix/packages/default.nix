{
  perSystem = {config, ...}: let
    inherit
      (config)
      craneLib
      commonArgs
      commonArgsNative
      cargoArtifacts
      cargoArtifactsNative
      ;
  in {
    packages = {
      fast-delete = craneLib.buildPackage (commonArgs
        // {
          inherit cargoArtifacts;
        });

      fast-delete-native = craneLib.buildPackage (commonArgsNative
        // {
          cargoArtifacts = cargoArtifactsNative;
        });
    };
  };
}
