top @ {lib, ...}: {
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

    mkFlags = flags: lib.concatStringsSep " " (map (x: "-C ${x}") flags);

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

        buildInputs = lib.optionals stdenv.hostPlatform.isDarwin [
          libcxx
          pkgs.apple-sdk_15
        ];

        nativeBuildInputs = [
          clang
          bintools
        ];
      }
      // (builtins.removeAttrs args ["flags"]);
  in {
    options = {
      commonArgs = lib.mkOption {
        type = lib.types.attrs;
        default = mkCommonArgs {inherit flags;};
      };

      commonArgsNative = lib.mkOption {
        type = lib.types.attrs;

        default = mkCommonArgs {
          flags = flags ++ ["target-cpu=${top.config.native}"];
          NIX_ENFORCE_NO_NATIVE = 0;
        };
      };
    };
  };
}
