# Minimal bash config.
#
# zsh is the daily shell — see zsh/ for the real setup. This exists so that a
# server that only has bash, or a script that runs under `bash -l`, still gets
# the same PATH and the same handful of tools.

# Interactive-only from here down.
case $- in
  *i*) ;;
  *) return ;;
esac

# ---------------------------------------------------------------------------
# History
# ---------------------------------------------------------------------------
HISTSIZE=50000
HISTFILESIZE=50000
HISTCONTROL=ignoreboth:erasedups
shopt -s histappend
shopt -s checkwinsize

# ---------------------------------------------------------------------------
# Homebrew — same three-location probe as zsh/zshrc.d/base.zsh
# ---------------------------------------------------------------------------
for brew_path in \
  /opt/homebrew/bin/brew \
  /usr/local/bin/brew \
  /home/linuxbrew/.linuxbrew/bin/brew \
  "$HOME/.linuxbrew/bin/brew"
do
  if [ -x "$brew_path" ]; then
    eval "$("$brew_path" shellenv)"
    break
  fi
done
unset brew_path

export HOMEBREW_NO_ANALYTICS=1
export HOMEBREW_NO_AUTO_UPDATE=1

# ---------------------------------------------------------------------------
# PATH
# ---------------------------------------------------------------------------
path_prepend() {
  [ -d "$1" ] || return 0
  case ":$PATH:" in
    *":$1:"*) return 0 ;;
  esac
  export PATH="$1:$PATH"
}

export GOPATH="$HOME/go"
export CARGO_HOME="${CARGO_HOME:-$HOME/.cargo}"
export BUN_INSTALL="$HOME/.bun"

path_prepend "$HOME/.local/bin"
path_prepend "$GOPATH/bin"
path_prepend "$CARGO_HOME/bin"
path_prepend "$BUN_INSTALL/bin"
path_prepend "/usr/local/go/bin"

export EDITOR="${EDITOR:-vim}"
export LANG="${LANG:-en_US.UTF-8}"

# ---------------------------------------------------------------------------
# Tools
# ---------------------------------------------------------------------------
[ -f "$HOME/.fzf.bash" ] && . "$HOME/.fzf.bash"
[ -f "$CARGO_HOME/env" ] && . "$CARGO_HOME/env"

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

command -v pyenv >/dev/null 2>&1 && eval "$(pyenv init -)"

# Ruby — gems installed with `gem install --user-install` (pod, rubocop, rufo).
command -v ruby >/dev/null 2>&1 && path_prepend "$(ruby -e 'puts Gem.user_dir' 2>/dev/null)/bin"

# Go — GVM for the legacy Go lines (`gvm use go1.19.1`).
[ -s "$HOME/.gvm/scripts/gvm" ] && . "$HOME/.gvm/scripts/gvm"

# Java — SDKMAN! (needs bash 4+; macOS /bin/bash is 3.2). Keep last: it edits PATH.
export SDKMAN_DIR="$HOME/.sdkman"
[ "${BASH_VERSINFO[0]}" -ge 4 ] && [ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ] && . "$SDKMAN_DIR/bin/sdkman-init.sh"

# ---------------------------------------------------------------------------
# Aliases — the subset worth having outside zsh
# ---------------------------------------------------------------------------
alias ll="ls -lh"
alias la="ls -lah"
alias k="kubectl"
alias tf="terraform"
alias myip="curl -s https://ipecho.net/plain; echo"

# ---------------------------------------------------------------------------
# Prompt — user@host cwd (git branch)
# ---------------------------------------------------------------------------
__git_branch() {
  git symbolic-ref --short HEAD 2>/dev/null | sed 's/^/ (/;s/$/)/'
}
PS1='\[\033[32m\]\u@\h\[\033[0m\]:\[\033[34m\]\w\[\033[33m\]$(__git_branch)\[\033[0m\]\$ '

# Machine-local overrides — secrets and work paths, gitignored.
[ -f "$HOME/.bashrc.local" ] && . "$HOME/.bashrc.local"
