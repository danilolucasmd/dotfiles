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

Every screen at a glance. The sections below repeat each value with the reason
behind it. Bold marks the values that are not archinstall's default, or that
`install.sh` depends on.

| Screen | Value |
| --- | --- |
| Installer language | English (US) |
| Locales | default |
| Mirror region | Brazil |
| **Repositories** | **default** — leave multilib off |
| Disk layout | Best-effort default partition layout |
| Filesystem | **btrfs**, default subvolume layout |
| Disk encryption | your call |
| Swap | default (gives you zram) |
| Bootloader | default (systemd-boot) — `install.sh` migrates it to Limine |
| Kernel | default (`linux`) |
| Hostname | anything |
| Authentication | create a user, type **Superuser (wheel)**; root **Disabled** |
| Profile | Minimal — no desktop, no greeter |
| Applications | None |
| Audio | None |
| **Network configuration** | **Use NetworkManager** |
| **Additional packages** | **git** |
| Timezone | America/Sao_Paulo |
| NTP | Enabled |

### Language
- Installer language: English (US)

### Locales
- Locales: default

### Mirrors and Repositories
- Mirror region: Brazil
- Repositories: default

Leave multilib off. Every package `install.sh` pulls from the official repos
lives in `core` or `extra`; nothing needs the 32-bit tree.

### Disk Configuration
- Disk layout: Best-effort default partition layout
- Disk encryption: your call
- Filesystem: **btrfs**, with the default subvolume layout

Encryption is a preference, not a requirement — `install.sh` behaves the same
either way.

**btrfs is the one value here that matters.** `install.sh` builds the whole
snapshot and recovery story on top of it: snapper, snap-pac and Limine, so that
every pacman transaction is snapshotted and every snapshot is bootable. Picking
ext4 is supported — the script skips the entire section when `/` is not btrfs —
but you lose that safety net completely.

The best-effort layout gives a 1 GiB ESP mounted at `/boot`, which is enough:
`install.sh` trims the initramfs to fit snapshot kernels into it. If you are
partitioning by hand anyway, give the ESP 2 GiB and stop thinking about it.
See `README.md` section 10 for why that number exists.

### Swap
- Swap: default

### Bootloader
- Bootloader: default (systemd-boot)

Take archinstall's default and let `install.sh` deal with it. It installs Limine
and `limine-snapper-sync` afterwards, which is what puts snapshots in the boot
menu paired with the kernel each one was taken with — the thing neither
systemd-boot nor grub-btrfs does on this layout, because `/boot` is the ESP and
kernels live outside every snapshot.

The migration keeps the systemd-boot EFI binary and its NVRAM entry in place as
a fallback, so a first reboot that goes wrong still has somewhere to land.

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

### Audio
- Audio: None

`install.sh` installs PipeWire (with `pipewire-pulse`, `pipewire-alsa` and
`wireplumber`), so letting archinstall pick an audio server only risks a second
one fighting it.

### Network Configuration
- Network configuration: **Use NetworkManager**

Not "Copy ISO network configuration". That sets up systemd-networkd, which
`install.sh` then masks — service and sockets both — because Proton VPN's Linux
app only ships a NetworkManager backend and the two cannot share an interface.
Choosing NetworkManager here means they agree from the start and nothing has to
change hands at the final reboot.

Prefer wired ethernet for the install itself. The wifi dongle needs a DKMS
module that `install.sh` builds, so it cannot carry the network before then, and
the run wants a steady connection for the AUR builds and clones.

### Additional Packages
- Additional packages: `git`

Only to clone this repo below. Everything else the script needs —
`base-devel`, `stow`, `sddm`, PipeWire — it installs itself.

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

Expect the first run to take a while: it builds AUR packages, including a DKMS
kernel module for the wifi dongle. Anything that fails on its own is reported
and skipped, and the script lists what it skipped at the end — check that list
before rebooting.
