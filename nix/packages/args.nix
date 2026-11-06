top @ {lib, ...}: let
  inherit
    (lib)
    concatStringsSep
    optionals
    ;
in {
  perSystem = {
    config,
    pkgs,
    ...
  }: let
    inherit
      (pkgs.llvmPackages_latest)
      stdenv
      clang
      bintools
      libcxx
      ;

    mkFlags = flags: concatStringsSep " " (map (x: "-C ${x}") flags);

    flags = [
      "linker=${clang}/bin/cc"
      "link-args=-fuse-ld=lld"
    ];

    mkCommonArgs = args @ {flags, ...}:
      {
        src = config.craneLib.cleanCargoSource top.config.src;
        strictDeps = true;
        enableParallelBuilding = true;
        RUSTFLAGS = mkFlags flags;

        buildInputs = optionals stdenv.hostPlatform.isDarwin [
          libcxx
        ];

        nativeBuildInputs = [
          clang
          bintools
        ];

        NIX_ENFORCE_NO_NATIVE = 0;
      }
      // (builtins.removeAttrs args ["flags"]);
  in {
    options = {
      commonArgs = lib.mkOption {
        type = lib.types.attrs;
        default = mkCommonArgs {
          flags = flags ++ optionals stdenv.hostPlatform.isDarwin ["target-cpu=${top.config.native}"];
        };
      };

      commonArgsNative = lib.mkOption {
        type = lib.types.attrs;

        default = mkCommonArgs {
          flags = flags ++ ["target-cpu=native"];
        };
      };
    };
  };
}
