# Arch Linux Fresh Install – Manual & System Notes

This repository provides a reproducible setup for a fresh Arch Linux installation
using:

- pacman + yay for packages
- GNU Stow for dotfiles (user and system)
- A single install.sh bootstrap script

Most of the system is fully automated.
This document describes what is intentionally manual and what requires
special attention over time.

---

## 1. Nautilus Sidebar

Add the following directories to Nautilus’ left sidebar manually:

- Code
- Downloads
- Pictures

This is intentionally not automated.

---

## 2. Brave Browser Language Settings

In Brave settings:

1. Add Portuguese (Brazil) to Languages
2. Enable spell check for:
   - English
   - Portuguese (Brazil)

---

## 3. 1Password

After installation:

- Open 1Password
- Sign in
- Enable browser integration if desired
- Enable developer options (ssh keys)

---

## 4. General Notes

- install.sh is safe to re-run
- System-level dotfiles live in dotfiles/system/
- User dotfiles are applied via standard stow
- All non-deterministic or GUI-based steps are documented here on purpose

If something breaks after a system update, this file is the single source of
truth for restoring expected behavior.
