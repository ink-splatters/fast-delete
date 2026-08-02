top @ {inputs, ...}: {
  perSystem = {
    config,
    pkgs,
    ...
  }: let
    inherit (config) craneLib commonArgs cargoArtifacts;
    crate = (builtins.fromTOML (builtins.readFile "${top.config.src}/Cargo.toml")).package;
  in {
    checks = {
      inherit (config.packages) fast-delete;

      cargo-audit = craneLib.cargoAudit {
        inherit (top.config) src;
        inherit (inputs) advisory-db;
        pname = crate.name;
        inherit (crate) version;
      };

      cargo-clippy = craneLib.cargoClippy (
        commonArgs
        // {
          inherit cargoArtifacts;
          cargoClippyExtraArgs = "--all-targets -- --deny warnings";
        }
      );

      cargo-doc = craneLib.cargoDoc (
        commonArgs
        // {
          inherit cargoArtifacts;
        }
      );

      cargo-deny = craneLib.cargoDeny {
        inherit (top.config) src;
        cargoDenyChecks = "bans licenses sources";
      };

      cargo-fmt = craneLib.cargoFmt {
        inherit (top.config) src;
      };

      cargo-nextest = craneLib.cargoNextest (
        commonArgs
        // {
          inherit cargoArtifacts;
          partitions = 1;
          partitionType = "count";
        }
      );

      fast-delete-udeps = craneLib.mkCargoDerivation (
        commonArgs
        // {
          inherit cargoArtifacts;
          pnameSuffix = "-udeps";
          buildPhaseCargoCommand = "cargo udeps --locked --all-targets";
          doInstallCargoArtifacts = false;
          nativeBuildInputs =
            (commonArgs.nativeBuildInputs or [])
            ++ [
              pkgs.cargo-udeps
            ];
        }
      );
    };
  };
}
