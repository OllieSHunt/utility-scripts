{ stdenv, nushell, sshfs, wget }:

stdenv.mkDerivation {
  pname = "offline-web";
  version = "0.0.1";

  src = ./.;

  buildInputs = [ nushell sshfs wget ];

  installPhase = ''
    install -Dm755 $src/offline-web.nu $out/bin/oweb
  '';
}
