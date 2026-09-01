#!/usr/bin/env bash
#
# install.sh — bootstrap a fresh macOS install with Homebrew packages.
#
# Usage: ./install.sh
#
# Installs Homebrew (if missing), then all CLI/TUI formulae and UI casks.
# Individual package failures are reported but do not abort the run, so the
# script always attempts every package and summarises what failed at the end.

set -uo pipefail

# ---------------------------------------------------------------------------
# Packages
# ---------------------------------------------------------------------------

# CLI / TUI tools (Homebrew formulae).
CLI_PACKAGES=(
  biome
  blueutil
  btop
  htop
  ffmpeg
  fzf
  fzf-tab
  gitleaks
  lazygit
  hunk
  neovim
  node
  nvm
  pnpm
  poppler
  ripgrep
  sevenzip
  smudge/smudge/nightlight
  stow
  tmux
  yazi
  zoxide
  zsh-autosuggestions
  zsh-syntax-highlighting
)

# GUI / UI applications (Homebrew casks).
UI_PACKAGES=(
  nikitabobko/tap/aerospace
  brave-browser
  docker
  ghostty
  karabiner-elements
  linearmouse
  vlc
)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

FAILED=()

info()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()    { printf '\033[1;32m  ✓\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33m  !\033[0m %s\n' "$*"; }

# install_formula <name>
install_formula() {
  local pkg="$1"
  if brew list --formula "$pkg" &>/dev/null; then
    ok "$pkg (already installed)"
    return
  fi
  info "Installing $pkg"
  if brew install "$pkg"; then
    ok "$pkg"
  else
    warn "Failed to install $pkg"
    FAILED+=("$pkg")
  fi
}

# install_cask <name>
install_cask() {
  local pkg="$1"
  if brew list --cask "$pkg" &>/dev/null; then
    ok "$pkg (already installed)"
    return
  fi
  info "Installing $pkg (cask)"
  if brew install --cask "$pkg"; then
    ok "$pkg"
  else
    warn "Failed to install $pkg"
    FAILED+=("$pkg (cask)")
  fi
}

# ---------------------------------------------------------------------------
# Homebrew
# ---------------------------------------------------------------------------

if ! command -v brew &>/dev/null; then
  info "Homebrew not found — installing"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  # Add brew to PATH for the rest of this script (Apple Silicon vs Intel).
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
else
  ok "Homebrew already installed"
fi

info "Updating Homebrew"
brew update

# ---------------------------------------------------------------------------
# Install
# ---------------------------------------------------------------------------

info "Installing CLI / TUI packages"
for pkg in "${CLI_PACKAGES[@]}"; do
  install_formula "$pkg"
done

info "Installing UI packages (casks)"
for pkg in "${UI_PACKAGES[@]}"; do
  install_cask "$pkg"
done

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

echo
if (( ${#FAILED[@]} == 0 )); then
  ok "All packages installed successfully."
else
  warn "The following packages failed to install:"
  for pkg in "${FAILED[@]}"; do
    printf '    - %s\n' "$pkg"
  done
  echo
  warn "Note: 'fzf-tab' is a zsh plugin with no Homebrew formula; it is"
  warn "normally sourced from a cloned repo via your zsh plugin setup."
  exit 1
fi
