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
plugins=(gitfast)
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
# `copy`: send stdin to the clipboard minus the trailing newline, so pasted text
# doesn't arrive with a line break attached. Optional filters, applied in order:
#   --strip <re>  delete the first match of a Perl regex on each line
#   --only <re>   copy only the matching part of each line; if the regex has a
#                 capture group, only that group. Non-matching lines are dropped
#   --hist        preset: --strip '^[[:space:]]*[0-9]+[[:space:]]+', which turns
#                 "2298  git status" into "git status". For `history | fzf | copy --hist`
# Examples:
#   history | fzf | copy --hist
#   git branch --show-current | copy --only '[a-z]+-[0-9]+'   # ddias/vend-2516-x -> vend-2516
#   cat notes.md | copy --strip '^> '
function copy() {
  local strip_re='' only_re=''
  while (( $# )); do
    case "$1" in
      --hist)    strip_re='^[[:space:]]*[0-9]+[[:space:]]+' ;;
      --strip=*) strip_re="${1#--strip=}" ;;
      --only=*)  only_re="${1#--only=}" ;;
      --strip|--only)
        if (( $# < 2 )); then
          print -ru2 -- "copy: $1 needs a regex"
          return 2
        fi
        [[ "$1" == --strip ]] && strip_re="$2" || only_re="$2"
        shift
        ;;
      --help|-h)
        print -r -- 'usage: <command> | copy [--hist] [--strip <re>] [--only <re>]'
        return 0
        ;;
      *)
        print -ru2 -- "copy: unknown option: $1"
        return 2
        ;;
    esac
    shift
  done

  local text
  text=$(cat)
  if [[ -n "$strip_re" ]]; then
    text=$(print -r -- "$text" | re="$strip_re" perl -pe 's/$ENV{re}//') || return
  fi
  if [[ -n "$only_re" ]]; then
    text=$(print -r -- "$text" | re="$only_re" perl -nle 'print(defined $1 ? $1 : $&) if /$ENV{re}/') || return
  fi
  print -rn -- "$text" | pbcopy
}
alias bt="btui"

source ~/.safe-chain/scripts/init-posix.sh # Safe-chain Zsh initialization scriptexport PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"

# opencode
export PATH=/Users/ddias/.opencode/bin:$PATH

# lazygit: read config from ~/.config (stow-managed); macOS default is elsewhere
export LG_CONFIG_FILE="$HOME/.config/lazygit/config.yml"

# oh-my-zsh
zstyle ':omz:alpha:lib:git' async-prompt no

# safe-chain: ensure binary is found before asdf/mise shims
export PATH="/Users/ddias/.safe-chain/bin:$PATH"
source ~/.safe-chain/scripts/init-posix.sh # Safe-chain Zsh initialization script

# 1. Ghost-text history suggestions (Warp style)
source $(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh

# 2. Rich Tab Completion Menu (Only triggers when hitting Tab)
source $(brew --prefix)/opt/fzf-tab/share/fzf-tab/fzf-tab.zsh
zstyle ':completion:*:git-checkout:*' sort false
zstyle ':fzf-tab:*' fzf-command ftb-tmux-popup

# 3. Syntax highlighting (Must always remain at the very bottom)
source $(brew --prefix)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# Disable auto_cd (Oh My Zsh enables it): typing a bare directory name like
# `claude` should run the command / error, not silently cd into the folder.
# Must come after `source $ZSH/oh-my-zsh.sh` so it overrides OMZ's setopt.
unsetopt auto_cd

# Ctrl+L: do nothing (don't clear the screen). Bound to an empty widget so the
# keypress is swallowed silently instead of running zsh's clear-screen.
function _noop() { }
zle -N _noop
bindkey '^L' _noop

# `history`: at the terminal, print commands with no leading event numbers. Oh My
# Zsh aliases `history` to a wrapper that always runs `fc -l`, which numbers every
# line; `fc -ln` drops the numbers. When the output is piped the numbers are kept,
# so they stay visible in `history | fzf`; strip them on the way to the clipboard
# with `copy --hist`. Must come after `source $ZSH/oh-my-zsh.sh` so it overrides
# OMZ's alias.
unalias history 2>/dev/null
function history() {
  # -c (clear) and the timestamp flags (-f/-E/-i/-t) go back to the OMZ wrapper;
  # everything else, including relative ranges like `history -20`, is listed here.
  case "$1" in
    -c|-f|-E|-i|-t) omz_history "$@"; return ;;
  esac
  if [[ -t 1 ]]; then
    builtin fc -ln ${@:-1}
  else
    builtin fc -l ${@:-1}
  fi
}
