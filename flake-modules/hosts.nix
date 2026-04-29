# Public-scope host declarations with placeholder identity.
#
# The public flake ships two genuinely-useful standalone hosts: a
# VirtualBox NixOS installer and a WSL NixOS environment. Darwin and
# fedora/HM hosts are declared only in downstream private flakes — a
# darwin sample would require a Mac anyway, and downstream flakes
# always override the identity-sensitive bits.
{ inputs, ... }:
{
  easy-hosts.hosts = {
    vboxnixos = {
      class = "nixos";
      arch = "x86_64";
      path = ../hosts/nixos/vbox;
      modules = [
        (
          { config, ... }:
          {
            # Desktop HM bundle is vboxnixos-only. Attach via HM user imports.
            home-manager.users.${config.myOptions.user.username}.imports = [
              ../modules/shared/home/desktop
            ];
          }
        )
        # Needs disko module for declarative partitioning.
        (
          { ... }:
          {
            imports = [ inputs.disko.nixosModules.disko ];
          }
        )
      ];
    };

    wsl = {
      class = "nixos";
      arch = "x86_64";
      path = ../hosts/nixos/wsl;
      modules = [
        (
          { ... }:
          {
            imports = [ inputs.nixos-wsl.nixosModules.wsl ];
          }
        )
      ];
    };
  };
}
