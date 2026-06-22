# ~/.zshrc config for Arch Linux

# --- PATH Configuration ---
# System paths
export PATH=$HOME/.local/bin:$HOME/bin:/usr/local/bin:$PATH

# Composer global packages (Laravel, Pint, etc.)
if [ -d "$HOME/.config/composer/vendor/bin" ]; then
    export PATH="$HOME/.config/composer/vendor/bin:$PATH"
fi

# Bun packages
if [ -d "$HOME/.bun/bin" ]; then
    export PATH="$HOME/.bun/bin:$PATH"
fi

# NPM global binaries (if configured to a custom directory)
export PATH="$HOME/.cache/npm/global/bin:$PATH"

# --- Zsh History Settings ---
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
mkdir -p "$(dirname "$HISTFILE")"

set_opts=(
  HIST_FCNTL_LOCK HIST_IGNORE_DUPS HIST_IGNORE_SPACE SHARE_HISTORY
  NO_APPEND_HISTORY NO_EXTENDED_HISTORY NO_HIST_EXPIRE_DUPS_FIRST
  NO_HIST_FIND_NO_DUPS NO_HIST_IGNORE_ALL_DUPS NO_HIST_SAVE_NO_DUPS
)
for opt in "${set_opts[@]}"; do
  setopt "$opt"
done
unset opt set_opts

# --- Completion System ---
autoload -Uz compinit
compinit

# --- Key Bindings & Shell Settings ---
bindkey -e # Use Emacs keybindings (default)
KEYTIMEOUT=1

# --- Oh My Zsh Config ---
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="kphoen"
if [ -d "$ZSH" ]; then
    source "$ZSH/oh-my-zsh.sh"
fi

# --- Zsh Plugins (Arch Linux Paths) ---
# Autosuggestions
if [ -f /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]; then
    source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
    ZSH_AUTOSUGGEST_STRATEGY=(history)
fi

# Syntax Highlighting (load at the very end of the file)
if [ -f /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]; then
    source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
    ZSH_HIGHLIGHT_HIGHLIGHTERS=(main)
fi

# Zsh Help Directory
if [ -d "/usr/share/zsh/$ZSH_VERSION/help" ]; then
    HELPDIR="/usr/share/zsh/$ZSH_VERSION/help"
fi

# --- Helper Functions ---

# y() - Yazi wrapper to change directory on exit
function y() {
  local tmp="$(mktemp -t "yazi-cwd.XXXXX")"
  command yazi "$@" --cwd-file="$tmp"
  if cwd="$(<"$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
    builtin cd -- "$cwd"
  fi
  rm -f -- "$tmp"
}

# lg() - Lazygit wrapper to change directory on exit (if configured)
function lg() {
    export LAZYGIT_NEW_DIR_FILE=~/.lazygit/newdir
    command lazygit "$@"
    if [ -f $LAZYGIT_NEW_DIR_FILE ]; then
      cd "$(cat $LAZYGIT_NEW_DIR_FILE)"
      rm -f $LAZYGIT_NEW_DIR_FILE > /dev/null
    fi
}

# Kitty integration (if running inside Kitty)
if test -n "$KITTY_INSTALLATION_DIR"; then
  export KITTY_SHELL_INTEGRATION="no-rc"
  autoload -Uz -- "$KITTY_INSTALLATION_DIR"/shell-integration/zsh/kitty-integration
  kitty-integration
  unfunction kitty-integration
fi

# Load direnv integration if available
if command -v direnv &> /dev/null; then
    eval "$(direnv hook zsh)"
fi

# --- Aliases ---
alias clear='clear && printf '\''\033c'\'''
alias ff='fastfetch'

# Use eza instead of ls if available
if command -v eza &> /dev/null; then
    alias ls='eza -ha --icons=auto --sort=name --group-directories-first'
    alias ll='eza -lh --icons=auto'
else
    alias ls='ls -ah --color=auto'
    alias ll='ls -lh'
fi

# Arch Linux System Aliases (replacements for nixos-rebuild)
alias conf='cd ~/archdots'
alias upd='paru -Syu'

# Tool configs
export EDITOR='nvim'
export VISUAL='nvim'
