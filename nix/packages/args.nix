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
      "embed-bitcode=yes"
      "lto=thin"
    ];

    # CFLAGS = "-O3 -pipe";
    # CXXFLAGS = "-O3 -pipe";
    # LDFLAGS = "-fuse-ld=lld";
    # mkFlagsNative = flags: "${flags} -mcpu=${top.config.native}";

    mkCommonArgs = args @ {flags, ...}:
      {
        src = config.craneLib.cleanCargoSource top.config.src;
        strictDeps = true;
        enableParallelBuilding = true;
        RUSTFLAGS = "-Zdylib-lto " + (mkFlags flags);

        buildInputs = lib.optionals stdenv.hostPlatform.isDarwin [
          libcxx
        ];

        nativeBuildInputs =
          [
            clang
            bintools
          ]
          ++ lib.optionals stdenv.hostPlatform.isDarwin [
            pkgs.apple-sdk_15
          ];
        # inherit CFLAGS CXXFLAGS LDFLAGS;
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

          # CFLAGS = mkFlagsNative CFLAGS;
          # CXXFLAGS = mkFlagsNative CXXFLAGS;
        };
      };
    };
  };
}
