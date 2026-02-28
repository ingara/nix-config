# Hetzner Cloud NixOS Server Setup

How to deploy NixOS on a Hetzner Cloud instance and manage it with deploy-rs. This documents the process used for Lumar (CAX21) and can be repeated for future servers.

## Prerequisites

- Nix with flakes on your local machine
- SSH key added to Hetzner Cloud console
- Server created in Hetzner Cloud with any Linux OS (will be replaced)
- Server IP and hardware info (see below)

## 1. Gather Hardware Info

SSH into the new instance and collect:

```bash
ssh root@<IP> "uname -m && lsblk && ip link show"
# Also get the predictable network interface name:
ssh root@<IP> "udevadm info /sys/class/net/eth0 2>/dev/null | grep ID_NET_NAME_PATH"
```

Key values needed:
- **Architecture** — `aarch64` or `x86_64`
- **Disk device** — typically `/dev/sda` (virtio-scsi)
- **Network interface** — predictable name (e.g. `enp1s0`). Ubuntu may show `eth0` but NixOS uses predictable names.

## 2. Create Host Config

### Disk config — `hosts/nixos/<hostname>/disk-config.nix`

See `hosts/nixos/lumar/disk-config.nix` as a reference. Key points:
- CAX (ARM64) instances are **UEFI-only** — need an ESP partition (`type = "EF00"`), no EF02 (BIOS boot) needed
- x86_64 instances use **legacy BIOS** — need EF02 partition instead
- Btrfs with subvolumes (root, home, nix, persist) gives compression and snapshot support

### Host config — `hosts/nixos/<hostname>/default.nix`

See `hosts/nixos/lumar/default.nix` as a reference. Key points:

**Boot (UEFI / ARM64):**
```nix
boot.loader.grub = {
  efiSupport = true;
  efiInstallAsRemovable = true;  # critical for cloud VMs
  device = "nodev";
};
```

**Boot (BIOS / x86_64):**
```nix
boot.loader.grub = {
  enable = true;
  device = "/dev/sda";
};
```

**Networking — use systemd-networkd, not DHCP client:**
```nix
networking.useDHCP = false;
systemd.network.enable = true;
systemd.network.networks."30-wan" = {
  matchConfig.Name = "enp1s0";  # verify this for your instance
  networkConfig.DHCP = "ipv4";
};
```

**Required imports:**
- `../base.nix` — shared NixOS config (timezone, fish, user, sudo, nix settings)
- `./disk-config.nix` — disk layout
- `(modulesPath + "/profiles/qemu-guest.nix")` — Hetzner uses KVM/QEMU

**Required kernel modules for Hetzner Cloud:**
```nix
boot.initrd.availableKernelModules = [ "virtio_pci" "virtio_scsi" "sd_mod" "sr_mod" ];
boot.initrd.kernelModules = [ "virtio_gpu" ];  # ARM64 only
boot.kernelParams = [ "console=tty" ];          # ARM64 only
```

**SSH keys:** Add your Hetzner SSH key to both `root` and your user. Root access is needed for deploy-rs.

## 3. Add to flake.nix

### nixosConfigurations

Use `mkNixosHost`:

```nix
<hostname> = mkNixosHost {
  system = "aarch64-linux";  # or "x86_64-linux"
  hasGui = false;
  hostPath = ./hosts/nixos/<hostname>;
  extraModules = [ disko.nixosModules.disko ];
  # For git signing with a key file on the server:
  hmImports = [
    ({ lib, ... }: { programs.git.signing.key = lib.mkForce "/home/ingar/.ssh/signing_key"; })
  ];
};
```

### deploy-rs node

```nix
deploy.nodes.<hostname> = {
  hostname = "<hostname>";  # resolves via ~/.ssh/config — keeps IP out of public repo
  profiles.system = {
    sshUser = "root";
    user = "root";
    path = deploy-rs.lib.<system>.activate.nixos self.nixosConfigurations.<hostname>;
    remoteBuild = true;  # server builds its own config — avoids cross-arch issues
  };
};
```

## 4. SSH Config

Add to `~/.ssh/config`:

```
Host <hostname>
    HostName <IP>
    User ingar
    ForwardAgent yes
```

This keeps the IP out of the nix-config repo (which is public) and enables SSH agent forwarding for GitHub access via 1Password.

## 5. Git Signing Key

Export the signing private key from 1Password and prepare for deployment:

```bash
temp=$(mktemp -d)
mkdir -p "$temp/home/ingar/.ssh"
# Paste private key from 1Password into this file:
cat > "$temp/home/ingar/.ssh/signing_key" << 'EOF'
-----BEGIN OPENSSH PRIVATE KEY-----
<key content>
-----END OPENSSH PRIVATE KEY-----
EOF
chmod 600 "$temp/home/ingar/.ssh/signing_key"
```

The host config's activation script automatically fixes ownership to `ingar:users` on every boot.

## 6. Install NixOS

**Take a Hetzner Cloud snapshot first** as a rollback safety net.

```bash
nix run github:nix-community/nixos-anywhere -- \
  --flake .#<hostname> \
  --target-host root@<hostname> \
  --build-on-remote \
  --extra-files "$temp"
```

This takes 10-20 minutes. After completion:

```bash
rm -rf "$temp"
ssh-keygen -R <IP>
ssh-keygen -R <hostname>
```

## 7. Verify

```bash
ssh root@<hostname> "hostname && uname -m"        # NixOS running
ssh <hostname>                                      # user access with fish
ssh <hostname> "btrfs subvolume list /"              # btrfs subvolumes
ssh <hostname> "ssh -T git@github.com"               # GitHub agent forwarding
ssh <hostname> "git init /tmp/t && cd /tmp/t && git commit -S --allow-empty -m test && git cat-file -p HEAD && rm -rf /tmp/t"  # signing
ssh <hostname> "claude --version"                    # Claude Code
```

## 8. Ongoing Deployment

```bash
just deploy-<hostname>
# or directly:
nix run github:serokell/deploy-rs -- .#<hostname> --skip-checks
```

`--skip-checks` is correct when using `remoteBuild = true` — the server builds its own closure, so local checks (which would fail on a different arch) are unnecessary.

deploy-rs has **magic rollback**: if SSH connectivity is lost after activation (e.g. broken network config), the server automatically rolls back within 30 seconds.

## Architecture Notes

- **`remoteBuild = true`** — the server builds its own NixOS closure. This avoids cross-compilation issues when deploying from macOS (aarch64-darwin) or Fedora (x86_64-linux) to an aarch64-linux server.
- **`hostname` in deploy-rs** resolves via `~/.ssh/config`, not DNS. This keeps IPs out of the public repo.
- **SSH agent forwarding** (`ForwardAgent yes`) lets the server use your local 1Password SSH agent for GitHub access. No GitHub keys on the server.
- **Git signing** uses a deployed private key file with `ssh-keygen` (not `op-ssh-sign`), since the server has no 1Password GUI.
- **Hetzner CAX (ARM64)** is UEFI-only. x86_64 instances use legacy BIOS. Disk and boot config differ accordingly.
