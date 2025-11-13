{ config, pkgs, ... }:

{
  networking.useNetworkd = true;
  networking.useDHCP = false;

  systemd.network = {
    enable = true;

    networks."10-ens1" = {
      matchConfig.Name = "ens1";
      networkConfig = {
        DHCP = "no";
        IPv6AcceptRA = false;
      };
    };

    networks."20-ovsbr0" = {
      matchConfig.Name = "ovsbr0";
      networkConfig.DHCP = "yes";
      dhcpV4Config = {
        UseDNS = true;
        UseRoutes = true;
        UseGateway = true;
      };
    };
  };

  virtualisation.openvswitch = {
    enable = true;
    bridges.ovsbr0.ports = [ "ens1" ];
  };
}

