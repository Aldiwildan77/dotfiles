# PATH and environment variables.
#
# Nothing secret belongs in this file — it is committed. Tokens, passwords and
# work-specific endpoints go in ~/.zshrc.local (see .zshrc.local.example).

# path_prepend <dir> — add to the front of PATH, skipping missing dirs and
# duplicates. PATH edits are the single most common source of drift between
# machines, so everything below goes through here.
path_prepend() {
  [[ -d "$1" ]] || return 0
  case ":$PATH:" in
    *":$1:"*) return 0 ;;
  esac
  export PATH="$1:$PATH"
}

# ---------------------------------------------------------------------------
# User binaries
# ---------------------------------------------------------------------------
path_prepend "$HOME/.local/bin"     # pipx, poetry, uv
path_prepend "$HOME/bin"

# ---------------------------------------------------------------------------
# Go
# ---------------------------------------------------------------------------
export GOPATH="$HOME/go"
path_prepend "$GOPATH/bin"
path_prepend "/usr/local/go/bin"

## Skip protobuf conflict namespace
export GOLANG_PROTOBUF_REGISTRATION_CONFLICT=warn

# ---------------------------------------------------------------------------
# Rust
# ---------------------------------------------------------------------------
export CARGO_HOME="${CARGO_HOME:-$HOME/.cargo}"
path_prepend "$CARGO_HOME/bin"

# ---------------------------------------------------------------------------
# Node / Bun / Deno
# ---------------------------------------------------------------------------
export NVM_DIR="$HOME/.nvm"
export BUN_INSTALL="$HOME/.bun"
path_prepend "$BUN_INSTALL/bin"
export DENO_INSTALL="$HOME/.deno"
path_prepend "$DENO_INSTALL/bin"

# ---------------------------------------------------------------------------
# Python
# ---------------------------------------------------------------------------
export PYENV_ROOT="$HOME/.pyenv"
path_prepend "$PYENV_ROOT/bin"

# ---------------------------------------------------------------------------
# Ruby — gems installed with `gem install --user-install`
# ---------------------------------------------------------------------------
if command -v ruby >/dev/null 2>&1 && command -v gem >/dev/null 2>&1; then
  path_prepend "$(ruby -e 'puts Gem.user_dir' 2>/dev/null)/bin"
fi

# ---------------------------------------------------------------------------
# Homebrew keg-only formulae — not linked into the prefix, so they need PATH
# entries of their own. $HOMEBREW_PREFIX is set by base.zsh.
# ---------------------------------------------------------------------------
if [[ -n "$HOMEBREW_PREFIX" ]]; then
  path_prepend "$HOMEBREW_PREFIX/opt/php@8.4/bin"
  path_prepend "$HOMEBREW_PREFIX/opt/php@8.4/sbin"
  path_prepend "$HOMEBREW_PREFIX/opt/libpq/bin"        # psql, pg_dump
  path_prepend "$HOMEBREW_PREFIX/opt/mysql-client@8.0/bin"
  path_prepend "$HOMEBREW_PREFIX/opt/perl/bin"
  # GNU coreutils under their real names (ls, not gls)
  path_prepend "$HOMEBREW_PREFIX/opt/coreutils/libexec/gnubin"
fi

# ---------------------------------------------------------------------------
# macOS-only toolchains
# ---------------------------------------------------------------------------
if [[ "$DOTFILES_OS" == "macos" ]]; then
  export ANDROID_HOME="$HOME/Library/Android/sdk"
  path_prepend "$ANDROID_HOME/platform-tools"
  path_prepend "$ANDROID_HOME/tools"

  # Whatever JDK is current, rather than a hard-coded version path.
  if /usr/libexec/java_home >/dev/null 2>&1; then
    export JAVA_HOME="$(/usr/libexec/java_home 2>/dev/null)"
  fi
fi

# ---------------------------------------------------------------------------
# Linux-only
# ---------------------------------------------------------------------------
if [[ "$DOTFILES_OS" == "linux" ]]; then
  export ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/Sdk}"
  path_prepend "$ANDROID_HOME/platform-tools"
  [[ -z "$JAVA_HOME" && -d /usr/lib/jvm/default-java ]] && export JAVA_HOME=/usr/lib/jvm/default-java
fi
