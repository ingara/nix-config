# Gaming stack for NixOS (the `gaming` tag). programs.steam auto-pulls the
# 32-bit libraries + udev rules; hardware.graphics.enable32Bit provides the
# 32-bit GL/Vulkan that Proton and Wine titles need.
{ config, pkgs, ... }:
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
  programs.gamemode = {
    enable = true;
    # The iGPU heuristic reads root-only RAPL energy_uj and fails every
    # launch; the documented -1 doesn't disable it, only >= 10000
    # short-circuits the read (FeralInteractive/gamemode#367).
    settings.general.igpu_power_threshold = 10000;
  };
  # gamemode's polkit rule only lets this group run the governor/split-lock
  # helpers; outside it every game launch raises a password prompt.
  users.users.${config.myOptions.user.username}.extraGroups = [ "gamemode" ];

  # 32-bit OpenGL/Vulkan for Steam/Proton titles. (The driver itself —
  # videoDrivers + hardware.nvidia + hardware.graphics.enable — is the nvidia
  # tag's job; 32-bit support is a gaming concern.)
  hardware.graphics.enable32Bit = true;
}
