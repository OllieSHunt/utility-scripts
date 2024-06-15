# Utility Scripts
Some usefull nushell scripts.

## Scripts

### CPU Frequency Manager
A small utility that adjusts the CPU frequency governor.

command: `freq`

### Offline Web
A nushell script that greatly simplifies the process of making offline clones of websites.

command: `oweb` 

## Installation
If you are using nix then add the following to your `configuration.nix`:
```nix
environment.systemPackages = with pkgs; [
  (callPackage (builtins.fetchGit {
    url = "https://github.com/OllieSHunt/utility-scripts.git";
    ref = "main";
    rev = "<replace with the latest git commit hash>";
  }) {})
];
```
