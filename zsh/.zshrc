# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time Oh My Zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="robbyrussell"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
# zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
# Note: fzf-tab must come after zsh-autosuggestions (it wraps the
# completion widget).
# zsh-syntax-highlighting MUST be loaded last.
plugins=(git zsh-autosuggestions fzf-tab zsh-syntax-highlighting)

source $ZSH/oh-my-zsh.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='nvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch $(uname -m)"

# Set personal aliases, overriding those provided by Oh My Zsh libs,
# plugins, and themes. Aliases can be placed here, though Oh My Zsh
# users are encouraged to define aliases within a top-level file in
# the $ZSH_CUSTOM folder, with .zsh extension. Examples:
# - $ZSH_CUSTOM/aliases.zsh
# - $ZSH_CUSTOM/macos.zsh
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

# Aliases
## General
alias ls="ls --color=auto -l"
## Apps
alias bluetooth=bluetui
alias bt=bluetui
alias wifi=wifitui
alias audio=wiremix
alias vim=nvim
## Commands
alias lock=hyprlock
alias suspend="systemctl suspend"
alias logout="hyprctl dispatch exit"
alias copy="wl-copy --trim-newline"

# Set up fzf key bindings and fuzzy completion
source <(fzf --zsh)

# fzf-tab: fuzzy TAB completions
## Let fzf-tab take over zsh's menu so it can capture the prefix
zstyle ':completion:*' menu no
## Group support + filename colorizing in the completion list
zstyle ':completion:*:descriptions' format '[%d]'
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
## Don't sort `git checkout` candidates (keep ref ordering)
zstyle ':completion:*:git-checkout:*' sort false
## Preview directory contents when completing `cd`
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color=auto $realpath'
## Render the completion menu inline. ftb-tmux-popup was the floating-popup
## variant; herdr is the multiplexer now and has no equivalent, and the popup
## renderer hangs outside tmux rather than falling back.
zstyle ':fzf-tab:*' fzf-min-height 8

# Yazi setup
export EDITOR="nvim"

function y() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
	command yazi "$@" --cwd-file="$tmp"
	IFS= read -r -d '' cwd < "$tmp"
	[ -n "$cwd" ] && [ "$cwd" != "$PWD" ] && builtin cd -- "$cwd"
	rm -f -- "$tmp"
}

# Open Nautilus, detached from the terminal so it survives closing the shell.
# `open` with no args opens Nautilus at its default location, `open .` opens the
# current directory, `open ~/Code` opens that path.
function open() {
	nohup nautilus "$@" >/dev/null 2>&1 &!
}

# Anything installed outside pacman lands here: the Claude Code CLI, uv and
# the tools it installs (buds), pkg. Set here rather than relying on
# ~/.profile, which is written by those installers and is not in the dotfiles.
export PATH="$HOME/.local/bin:$PATH"

# Where `cargo install` drops binaries. rustup itself comes from pacman and its
# shims (cargo, rustc, ...) are already in /usr/bin, so this is only about
# crates installed from source -- and it means nothing has to source
# ~/.cargo/env, which lives outside the dotfiles.
export PATH="$HOME/.cargo/bin:$PATH"


# Disable auto_cd (Oh My Zsh enables it): typing a bare directory name like
# `claude` should run the command / error, not silently cd into the folder.
# Must come after `source $ZSH/oh-my-zsh.sh` so it overrides OMZ's setopt.
unsetopt auto_cd

# Ctrl+L: do nothing (don't clear the screen). Bound to an empty widget so the
# keypress is swallowed silently instead of running zsh's clear-screen.
function _noop() { }
zle -N _noop
bindkey '^L' _noop

# herdr sometimes leaves modifyOtherKeys / the kitty keyboard protocol enabled
# in a pane after an agent TUI exits. The shell never asked for either, so keys
# arrive as escape sequences (shift+enter -> ESC [ 27;2;13~) and zle gives up
# partway through, self-inserting the tail as `;2;13~`. Turn both protocols off
# before each prompt so the shell asserts its own preference. This is
# prompt-local: TUIs re-enable what they need on startup, so shift+enter still
# works normally inside Claude Code and friends.
function _reset_kbd_protocol() { printf '\e[>4;0m\e[<u' }
precmd_functions+=(_reset_kbd_protocol)

# Belt-and-braces for the window between a TUI exiting and the next prompt:
# treat a stray shift+enter as a plain Enter rather than pasting its tail.
bindkey '^[[27;2;13~' accept-line   # modifyOtherKeys encoding
bindkey '^[[13;2u'    accept-line   # kitty keyboard encoding

# React Native / Android development toolchain
export JAVA_HOME="$HOME/.local/share/jdks/current"
export ANDROID_HOME="$HOME/Android/Sdk"
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
