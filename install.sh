#!/usr/bin/env bash
set -euo pipefail

############################################################
#                                                          #
#                ARCH FRESH INSTALL SETUP                  #
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
  fcitx5 \
  fastfetch \
  nerd-fonts

############################################################
# 4. AUR HELPER (yay)                                      #
############################################################

if ! command -v yay &>/dev/null; then
  echo "==> Installing yay"
  git clone https://aur.archlinux.org/yay.git /tmp/yay
  (
    cd /tmp/yay
    makepkg -si --noconfirm
  )
fi

############################################################
# 5. PACMAN PACKAGES                                       #
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
  qt6ct \
  kvantum \
  kvantum-breeze-icons \
  xdg-desktop-portal-hyprland

############################################################
# 6. AUR PACKAGES                                          #
############################################################

echo "==> Installing AUR packages"
yay -S --needed --noconfirm \
  ghostty \
  walker-bin \
  elephant-desktopapplications-bin \
  elephant-clipboard-bin \
  ttf-joypixels \
  1password \
  brave-bin \
  orca-slicer-bin \
  bluetui \
  wiremix \
  btop

############################################################
# 7. NODE / NVM SETUP                                      #
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
# 8. DOTFILES (GNU STOW)                                   #
############################################################

echo "==> Applying dotfiles with stow"
cd "$HOME/dotfiles"

stow */

echo "==> Applying system dotfiles"
sudo stow -t / system
sudo stow -t / sddm

############################################################
# 9. FILE PERMISSIONS                                      #
############################################################

echo "==> Fixing executable permissions"
chmod +x \
  "$HOME/.config/waybar/scripts/mic.sh" \
  "$HOME/.config/sounds/scripts/toggle-mic.sh"

############################################################
# 10. SERVICES                                             #
############################################################

echo "==> Enabling services"
sudo systemctl enable sddm

############################################################
# 11. DEFAULT APPLICATIONS                                 #
############################################################

echo "==> Setting default applications"
xdg-mime default ghostty.desktop inode/directory

############################################################
# 12. GIT CONFIGURATION                                    #
############################################################

echo "==> Configuring git"
git config --global core.editor nvim
git config --global pull.rebase false
git config --global user.name "Danilo de Lucas"
git config --global user.email "danilolucasmd@gmail.com"

############################################################
# 13. DONE                                                 #
############################################################

echo "========================================================"
echo " Setup complete."
echo " Review README.md for remaining manual steps."
echo "========================================================"
