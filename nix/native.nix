{lib, ...}: {
  # -C target-cpu=...
  # -mcpu=...
  options.native = lib.mkOption {
    type = lib.types.str;
    default = "native";
  };
}
