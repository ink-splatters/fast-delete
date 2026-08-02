{importTree}: (importTree.filterNot (
    path:
      builtins.elem path ["/default.nix"]
      || builtins.match "/dev/.*" path != null
  )
  ./.)
