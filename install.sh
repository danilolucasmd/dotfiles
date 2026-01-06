#!/usr/bin/env bash
set -euo pipefail

SECONDS=0
trap 'echo; echo "Install finished in $((SECONDS / 60))m $((SECONDS % 60))s"' EXIT

############################################################
#                                                          #
#              ARCH LINUX FRESH INSTALL SETUP               #
#                                                          #
############################################################

############################################################
# 0. PRE-FLIGHT CHECKS                                     #
############################################################

if [[ $EUID -eq 0 ]]; then
  echo "Do not run this script as root."
  exit 1
fi

command -v sudo >/dev/null || {
  echo "sudo is required."
  exit 1
}

############################################################
# 1. DIRECTORY STRUCTURE                                   #
############################################################

echo "==> Creating directories"
mkdir -p \
  "$HOME/Downloads" \
  "$HOME/Pictures/Screenshots"

############################################################
# 2. DEBLOAT DEFAULT PACKAGES                              #
############################################################

echo "==> Removing unwanted packages"
sudo pacman -Rns --noconfirm \
  kitty \
  dolphin \
  wofi ||
  true

############################################################
# 3. CORE SYSTEM TOOLS                                     #
############################################################

echo "==> Installing core tools"
sudo pacman -Syu --needed --noconfirm \
  base-devel \
  git \
  sudo \
  curl \
  fcitx5 \
  fastfetch \
  nerd-fonts \
  stow

############################################################
# 4. AUR HELPER (yay)                                      #
############################################################

if ! command -v yay >/dev/null 2>&1; then
  echo "==> Installing yay (yay-bin)"

  sudo pacman -S --needed --noconfirm base-devel git

  tmpdir="$(mktemp -d)"
  git clone https://aur.archlinux.org/yay-bin.git "$tmpdir"

  (
    cd "$tmpdir" || exit 1
    makepkg -si --noconfirm --needed
  )

  rm -rf "$tmpdir"
fi

############################################################
# 5. HYPRLAND + WAYLAND STACK                              #
############################################################

echo "==> Installing Hyprland and Wayland stack"

sudo pacman -S --needed --noconfirm \
  hyprland \
  wayland \
  xorg-xwayland \
  xdg-desktop-portal \
  xdg-desktop-portal-hyprland \
  qt5-wayland \
  qt6-wayland \
  pipewire \
  wireplumber \
  grim \
  slurp \
  polkit \
  polkit-gnome

############################################################
# 6. CORE / DEV / CLI PACKAGES                             #
############################################################

echo "==> Installing pacman packages"

sudo pacman -S --needed --noconfirm \
  stow \
  tmux \
  neovim \
  lazygit \
  fzf \
  ripgrep \
  fd \
  wl-clipboard \
  unzip \
  yazi \
  ffmpeg \
  p7zip \
  jq \
  poppler \
  zoxide \
  imagemagick \
  hyprpaper \
  hyprlock \
  hypridle \
  hyprshot \
  hyprpicker \
  nautilus \
  sushi \
  pika-backup \
  adw-gtk-theme \
  qt5ct \
  qt6ct

############################################################
# 7. AUR PACKAGES                                         #
############################################################

echo "==> Installing AUR packages"

sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1

yay -S --needed --noconfirm \
  ghostty \
  elephant-bin \
  elephant-desktopapplications-bin \
  elephant-clipboard-bin \
  walker-bin \
  ttf-joypixels \
  1password \
  brave-bin \
  orca-slicer-bin \
  bluetui \
  wiremix \
  btop

############################################################
# 8. NODE / NVM SETUP                                      #
############################################################

echo "==> Installing nvm and Node.js"

if [[ ! -d "$HOME/.nvm" ]]; then
  curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
fi

export NVM_DIR="$HOME/.nvm"
# shellcheck disable=SC1091
source "$NVM_DIR/nvm.sh"

nvm install --lts
npm install -g tree-sitter-cli

############################################################
# 9. SYSTEM DOTFILES
############################################################

echo "==> Applying system dotfiles"
cd "$HOME/dotfiles"
sudo stow -t / sddm

############################################################
# 10. USER DOTFILES
############################################################

echo "==> Applying user dotfiles"
stow */

############################################################
# 11. FILE PERMISSIONS                                     #
############################################################

echo "==> Fixing executable permissions"

chmod +x \
  "$HOME/.config/waybar/scripts/mic.sh" \
  "$HOME/.config/sounds/scripts/toggle-mic.sh"

############################################################
# 12. DISPLAY MANAGER (SDDM)                                #
############################################################

echo "==> Installing and enabling SDDM"

# sudo pacman -S --needed --noconfirm sddm
# sudo systemctl enable sddm

############################################################
# 13. DEFAULT APPLICATIONS                                 #
############################################################

echo "==> Setting default applications"
xdg-mime default ghostty.desktop inode/directory

############################################################
# 14. GIT CONFIGURATION                                    #
############################################################

echo "==> Configuring git"

git config --global core.editor nvim
git config --global pull.rebase false
git config --global user.name "Danilo de Lucas"
git config --global user.email "danilolucasmd@gmail.com"

############################################################
# 15. SANITY CHECKS                                        #
############################################################

command -v Hyprland >/dev/null || {
  echo "ERROR: Hyprland not found."
  exit 1
}

ls /usr/share/wayland-sessions/hyprland.desktop >/dev/null || {
  echo "ERROR: Hyprland session file missing."
  exit 1
}

############################################################
# 16. DONE                                                 #
############################################################

echo "========================================================"
echo " Setup complete."
echo " Reboot and log into the Hyprland session."
echo " Review README.md for remaining manual steps."
echo "========================================================"
