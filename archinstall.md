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
- Filesystem: default

### Swap
- Swap: default

### Bootloader
- Bootloader: default

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
sudo pacman -S --needed git base-devel
git clone <your-dotfiles-repo>
cd dotfiles
./install.sh
```
