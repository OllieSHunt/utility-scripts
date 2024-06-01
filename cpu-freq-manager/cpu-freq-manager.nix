{ stdenv, nushell }:

stdenv.mkDerivation {
  pname = "cpu-freq-manager";
  version = "0.0.1";

  src = ./.;

  buildInputs = [ nushell ];

  installPhase = ''
    install -Dm755 $src/cpu-freq-manager.nu $out/bin/freq
  '';
}
