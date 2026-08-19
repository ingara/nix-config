# NVIDIA GPU driver (the `nvidia` tag): the driver, modesetting, and hardware
# graphics, on the production branch. 32-bit GL lives in the gaming tag (it's a
# gaming concern); display-topology quirks (framebuffer pins, card selection)
# are host-specific and stay in the host.
{ config, ... }:
{
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.graphics.enable = true;

  hardware.nvidia = {
    modesetting.enable = true;
    open = true;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.production;
  };
}
