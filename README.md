# Utility Scripts
Some usefull nushell scripts.

To use them add the following to your `configuration.nix`:
```nix
environment.systemPackages = with pkgs; [
  (callPackage (builtins.fetchGit {
    url = "git@github.com:OllieSHunt/utility-scripts.git";
    ref = "main";
    rev = "<replace with the latest git commit hash>";
  }) {})
];
```
