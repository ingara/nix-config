# Gaming stack for NixOS (the `gaming` tag). programs.steam auto-pulls the
# 32-bit libraries + udev rules; hardware.graphics.enable32Bit provides the
# 32-bit GL/Vulkan that Proton and Wine titles need.
{ pkgs, ... }:
{
  programs.steam = {
    enable = true;
    gamescopeSession.enable = true;
    extraCompatPackages = [ pkgs.proton-ge-bin ];
    # MangoHud inside Steam's FHS so the Vulkan layer resolves under
    # pressure-vessel (the SLR sandbox doesn't bind-mount /nix/store, so the
    # session-wide implicit layer's absolute store path fails to load there —
    # works on the desktop, silently no-ops in Proton games without this).
    extraPackages = [ pkgs.mangohud ];
    remotePlay.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;
  };

  programs.gamescope.enable = true;
  programs.gamemode.enable = true;

  # 32-bit OpenGL/Vulkan for Steam/Proton titles. (The driver itself —
  # videoDrivers + hardware.nvidia + hardware.graphics.enable — is the nvidia
  # tag's job; 32-bit support is a gaming concern.)
  hardware.graphics.enable32Bit = true;
}
