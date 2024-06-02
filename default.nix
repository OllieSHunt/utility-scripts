{ callPackage, symlinkJoin }:

symlinkJoin {
  name = "utility-scripts";

  paths = [
    (callPackage ./cpu-freq-manager/default.nix {})
    (callPackage ./offline-web/default.nix {})
  ];
}
