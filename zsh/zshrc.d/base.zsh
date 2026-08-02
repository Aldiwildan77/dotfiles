# Theme, platform detection, Homebrew, history. Sourced first.

ZSH_THEME="robbyrussell"

# ---------------------------------------------------------------------------
# Platform detection — every other config file branches on $DOTFILES_OS
# ---------------------------------------------------------------------------
case "$OSTYPE" in
  darwin*)       export DOTFILES_OS="macos" ;;
  linux*)        export DOTFILES_OS="linux" ;;
  msys*|cygwin*) export DOTFILES_OS="windows" ;;
  *)             export DOTFILES_OS="unknown" ;;
esac

export DOTFILES_ARCH="$(uname -m)"

# ---------------------------------------------------------------------------
# Homebrew — one block covers Apple Silicon, Intel macOS and Linuxbrew
# ---------------------------------------------------------------------------
for brew_path in \
  /opt/homebrew/bin/brew \
  /usr/local/bin/brew \
  /home/linuxbrew/.linuxbrew/bin/brew \
  "$HOME/.linuxbrew/bin/brew"
do
  if [[ -x "$brew_path" ]]; then
    eval "$("$brew_path" shellenv)"
    break
  fi
done
unset brew_path

export HOMEBREW_NO_ANALYTICS=1
# Without this, every `brew install` first spends a few seconds fetching the
# formula index. Update deliberately with `brew update` instead.
export HOMEBREW_NO_AUTO_UPDATE=1

# ---------------------------------------------------------------------------
# History
# ---------------------------------------------------------------------------
export HISTSIZE=50000
export SAVEHIST=50000
export HISTFILE="$HOME/.zsh_history"
setopt HIST_IGNORE_SPACE
setopt HIST_REDUCE_BLANKS
setopt HIST_VERIFY
setopt INC_APPEND_HISTORY

# ---------------------------------------------------------------------------
# Locale, editor, pager
# ---------------------------------------------------------------------------
export LANG="${LANG:-en_US.UTF-8}"
export EDITOR="${EDITOR:-vim}"
export VISUAL="$EDITOR"
export PAGER="${PAGER:-less}"
export LESS="-R"
