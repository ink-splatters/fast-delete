{importTree}: (importTree.filterNot (
    path:
      builtins.elem path ["/default.nix"]
      || builtins.match "/flake.*" path != null
  )
  ./.)
