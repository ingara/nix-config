# Colima container runtime (declarative VM config + launchd auto-start).
#
# Replaces the bare `colima` package: the home-manager `services.colima` module
# pulls colima in via its `package` option, writes the profile colima.yaml, and
# installs a launchd agent that starts the VM at login.
#
# Backend is vz (Apple Virtualization.framework) instead of qemu, paired with
# virtiofs mounts (the recommended pairing for vz). qemu is unusable on M3/M4:
# qemu 11.0.0's HVF path asserts on the SME SMCR_EL1 register and can't init a
# vCPU, so the VM never boots.
#
# NOTE: vmType / disk geometry can't change in place. To change them, delete and
# re-provision the instance — back up any named docker volumes first, since the
# VM disk (and all volumes in it) is destroyed:
#     colima stop default && colima delete default
# then let the launchd agent (or `colima start default`) re-provision.
#
# colimaHomeDir is pinned to the XDG path ($XDG_CONFIG_HOME/colima) because
# colima >= 0.8 already defaults its home there; the module's stateVersion-gated
# default would otherwise pick legacy ~/.colima for us (stateVersion 23.11 < 26.05)
# and spawn a parallel instance, ignoring the existing ~/.config/colima one and
# warning "found ~/.colima, ignoring $XDG_CONFIG_HOME".
#
# DOCKER_HOST is left unset (the module only wires it at stateVersion >= 26.05);
# colima still registers its own "colima" docker context on activation, which
# our bare `docker` CLI picks up.
{ config, ... }:
{
  services.colima = {
    enable = true;
    colimaHomeDir = "${config.xdg.configHome}/colima";
    profiles.default = {
      # Defining `profiles.default` here overrides the module's option-level
      # default (which set these), so they must be restated: run as a launchd
      # service and be the active docker/k8s context. setDockerHost stays false
      # — at stateVersion < 26.05 colima registers its own "colima" docker
      # context on activation, which our bare `docker` CLI picks up.
      isService = true;
      isActive = true;
      settings = {
        # MUST be set or colima discards this entire file: `colima start`'s
        # prepareConfig treats a loaded config as "empty" when Runtime == ""
        # (config/config.go: `Empty() bool { return c.Runtime == "" }`) and
        # silently reverts to built-in defaults. Without this, vmType/mountType
        # happen to match the vz/virtiofs defaults so they appear to work, but
        # rosetta/disk/etc. are dropped. See abiosoft/colima cmd/start.go.
        runtime = "docker";

        vmType = "vz";
        mountType = "virtiofs";

        # rosetta is intentionally NOT enabled. On this stack (colima 0.10.1 /
        # lima 2.1.2) the in-guest rosetta setup fails under the launchd-agent
        # start: systemd-binfmt.service fails and rosettad.service exits
        # 203/EXEC, so no rosetta handler lands in binfmt_misc. amd64 emulation
        # is left to colima's default qemu binfmt (`binfmt = true`), which is
        # reliable. Revisit rosetta if a newer colima/lima fixes the guest side.

        cpu = 2;
        memory = 2;
        # Disk geometry MUST match the live instance: colima cannot shrink a
        # disk in place (`disk shrinking is not supported`), and because this is
        # a partial config any unset size is read as 0 — so `rootDisk` must be
        # stated explicitly or colima tries to resize the root disk to 0B and
        # the start fails fatally. 100/20 are colima's defaults, which the live
        # vz instance was created with. To change these, recreate the instance
        # (`colima delete default`) rather than editing in place.
        disk = 100;
        rootDisk = 20;
      };
    };
  };
}
