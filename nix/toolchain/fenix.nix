{lib, ...}: {
  perSystem = {
    config,
    inputs',
    ...
  }: {
    options.fenix = {
      packages = lib.mkOption {
        type = lib.types.attrs;
        readOnly = true;
      };

      util.combine = lib.mkOption {
        type = lib.types.functionTo lib.types.package;
        readOnly = true;
        description = "Combine Fenix components into a toolchain.";
      };
    };

    config.fenix = {
      packages = inputs'.fenix.packages;
      util.combine = config.fenix.packages.combine;
    };
  };
}
