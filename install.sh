# TODO - convert this into a script applying the following:
#
#### Dirs
# mkdir ~/Downloads
# mkdir ~/Pictures/Screenshots

#### Fixes
# exec cedilha fix (automate somehow): https://www.reddit.com/r/archlinux/comments/1fceq7p/cedilla_not_working_as_intended/?tl=pt-br

#### Debloat (pacman -R)
# dolphin
# wofi

#### Core
# kitty
# sddm
# git (maybe more stuff to add yay after)
# yay
# sudo pacman -S fcitx5 # For kb layout switching
# keyd

#### Install packages
# stow
# nvim
# lazygit
# nvm
# node (through nvm)
# tree-sitter-cli (globally through npm)
# fzf
# ripgrep
# fd
# wl-clipboard
# unzip
# yay -S ttf-joypixels

#### Launcher
# yay -S walker-bin
# yay -S elephant-desktopapplications-bin
# yay -S elephant-clipboard-bin

#### TUI apps
# bluetui
# wiremix
# btop

#### Hypr utilities
# hyprpaper
# hyprlock
# hypridle
# hyprshot
# hyprpicker

#### GUI apps
# 1password
# brave-bin
# nautilus
# sushi
# yay -S orca-slicer-bin
# sudo pacman -S pika-backup

#### Theme
# adw-gtk-theme
# qt5ct qt6ct kvantum kvantum breeze-icons
# xdg-desktop-portal-hyprland (maybe more stuff)

#### Stow
# stow <dotfiles> (might need to be doned before installing them)
# sudo stow -t / sddm
# sudo stow -t / keyd

#### Permissions
# chmod +x ~/.config/waybar/scripts/mic.sh
# chmod +x ~/.config/hypr/scripts/toggle-mic.sh

#### Services
# sudo systemctl enable --now keyd

#### Git
# git config --global core.editor "nvim"
# git config --global pull.rebase false
# git config --global user.name "Danilo de Lucas"
# git config --global user.email "danilolucasmd@gmail.com"

#### Manual settings
# 1 - Add the following directories to Nautilus' left nav
#     - Downloads
#     - Pictures
# 2 - Add pt-br to Brave's languages, and turn on Spell check for English and Portuguese
# 3 -
