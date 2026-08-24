# Arch Linux Installation Guide

## Arch Linux Installation (archinstall)

This setup assumes using the official **archinstall** installer from the Arch Linux ISO.

---

## 1. Boot the Arch ISO

- Boot from the official Arch Linux ISO
- Ensure you have a working internet connection

Start the installer:

```bash
archinstall
```

---

## 2. Archinstall Configuration

Use the following options when prompted:

### Language
- Installer language: English (US)

### Locales
- Locales: default

### Mirrors and Repositories
- Mirror region: Brazil
- Repositories: default

### Disk Configuration
- Disk layout: Best-effort default partition layout
- Disk encryption: Enabled
- Filesystem: **btrfs**, with the default subvolume layout

`install.sh` sets up snapper, snap-pac and grub-btrfs on top of this, so every
pacman transaction is snapshotted and bootable from the GRUB menu. Picking ext4
here is supported — the script skips the whole snapshot section when `/` is not
btrfs — but you lose that safety net.

### Swap
- Swap: default

### Bootloader
- Bootloader: **GRUB**

grub-btrfs is what puts snapshots in the boot menu, and it only works with GRUB.
systemd-boot (archinstall's default) has no equivalent.

### Kernels
- Kernel: default

### Hostname
- Hostname: archlinux (default)

### Authentication
- Create a user: Yes
- User type: Superuser (wheel)
- Root account: Disabled

### Profile
- Profile: Minimal

### Applications
- Applications: None

### Network Configuration
- Network configuration: Copy ISO network configuration

### Additional Packages
- Additional packages: None

### Timezone
- Timezone: America/Sao_Paulo

### NTP
- NTP: Enabled

---

## 3. Install and Reboot

- Review the configuration summary
- Proceed with installation
- Reboot when finished

Log in using the created user account.

---

## 4. Post-Install

After logging in:

```bash
sudo pacman -Syu
sudo pacman -S --needed git
git clone -b arch https://github.com/danilolucasmd/dotfiles.git ~/dotfiles
cd ~/dotfiles
chmod +x install.sh
./install.sh
```

Both details matter:

- **`-b arch`** — the repo's default branch is `omarchy`. A plain `git clone`
  checks that out and gives you a different setup entirely.
- **`~/dotfiles`** — `install.sh` refuses to run from anywhere else, and both
  `hyprland.conf` and the SDDM theme refer to that path directly.

Expect the first run to take a while: it builds AUR packages and the NVIDIA DKMS
modules. Anything that fails on its own is reported and skipped, and the script
lists what it skipped at the end — check that list before rebooting.
