{ lib, rustPlatform, pkg-config, openssl, dbus }:

rustPlatform.buildRustPackage rec {
  pname = "openflow-dbus";
  version = "0.1.0";

  src = ./.;

  cargoLock = {
    lockFile = ./Cargo.lock;
  };

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ openssl dbus ];

  meta = with lib; {
    description = "OpenFlow D-Bus Manager for Open vSwitch bridges";
    homepage = "https://github.com/ghostbridge/ghostbridge-nixos";
    license = licenses.mit;
    maintainers = [ ];
  };
}
