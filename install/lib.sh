#!/usr/bin/env bash
# Shared helpers for the install scripts. Source this, don't execute it.

# Resolve the repo root regardless of where the caller was invoked from.
DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export DOTFILES_DIR

# DRY_RUN=1 prints what would happen without touching the machine. Exported so
# that stage scripts spawned by bootstrap.sh inherit it.
DRY_RUN="${DRY_RUN:-0}"
export DRY_RUN

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
if [[ -t 1 ]]; then
  _C_RESET=$'\033[0m'; _C_BLUE=$'\033[34m'; _C_GREEN=$'\033[32m'
  _C_YELLOW=$'\033[33m'; _C_RED=$'\033[31m'; _C_DIM=$'\033[2m'
else
  _C_RESET=; _C_BLUE=; _C_GREEN=; _C_YELLOW=; _C_RED=; _C_DIM=
fi

log()   { printf '%s==>%s %s\n' "$_C_BLUE" "$_C_RESET" "$*"; }
ok()    { printf '%s  ok%s %s\n' "$_C_GREEN" "$_C_RESET" "$*"; }
warn()  { printf '%swarn%s %s\n' "$_C_YELLOW" "$_C_RESET" "$*" >&2; }
err()   { printf '%s err%s %s\n' "$_C_RED" "$_C_RESET" "$*" >&2; }
skip()  { printf '%sskip %s%s\n' "$_C_DIM" "$*" "$_C_RESET"; }
die()   { err "$*"; exit 1; }

# Run a command, honouring DRY_RUN.
run() {
  if [[ "$DRY_RUN" == "1" ]]; then
    printf '%s  would run:%s %s\n' "$_C_DIM" "$_C_RESET" "$*"
    return 0
  fi
  "$@"
}

has() { command -v "$1" >/dev/null 2>&1; }

# ---------------------------------------------------------------------------
# Platform detection
# ---------------------------------------------------------------------------

# Sets OS to one of: macos, linux, windows
detect_os() {
  case "${OSTYPE:-$(uname -s)}" in
    darwin*|Darwin*)                 OS=macos ;;
    linux*|Linux*)                   OS=linux ;;
    msys*|cygwin*|win32*|MINGW*)     OS=windows ;;
    *)                               OS=unknown ;;
  esac
  export OS
}

# Sets ARCH to one of: arm64, x86_64
detect_arch() {
  case "$(uname -m)" in
    arm64|aarch64) ARCH=arm64 ;;
    x86_64|amd64)  ARCH=x86_64 ;;
    *)             ARCH="$(uname -m)" ;;
  esac
  export ARCH
}

# Sets PKG_MGR to one of: apt, dnf, pacman, zypper, apk, brew — or empty.
detect_pkg_mgr() {
  PKG_MGR=
  for candidate in apt-get dnf pacman zypper apk; do
    if has "$candidate"; then
      PKG_MGR="${candidate%-get}"
      break
    fi
  done
  export PKG_MGR
}

# True when the script is running as root, or when sudo is available.
SUDO=
init_sudo() {
  if [[ "$(id -u)" -eq 0 ]]; then
    SUDO=
  elif has sudo; then
    SUDO=sudo
  else
    warn "not root and sudo is missing — system package installs will be skipped"
    SUDO=
  fi
  export SUDO
}

# ---------------------------------------------------------------------------
# Manifest parsing
# ---------------------------------------------------------------------------

# read_manifest <path> — echo one entry per line, stripping comments and blanks.
# Supports both whole-line comments and trailing `# ...` comments.
read_manifest() {
  local file="$1"
  [[ -f "$file" ]] || { warn "manifest not found: $file"; return 1; }
  sed -e 's/[[:space:]]*#.*$//' -e '/^[[:space:]]*$/d' "$file"
}

# ---------------------------------------------------------------------------
# Homebrew
# ---------------------------------------------------------------------------

# Put brew on PATH if it is installed but not yet exported (fresh shells, CI).
load_brew() {
  has brew && return 0
  local candidate
  for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew \
                   /home/linuxbrew/.linuxbrew/bin/brew "$HOME/.linuxbrew/bin/brew"; do
    if [[ -x "$candidate" ]]; then
      eval "$("$candidate" shellenv)"
      return 0
    fi
  done
  return 1
}

install_brew() {
  load_brew && { ok "homebrew already installed"; return 0; }
  log "installing homebrew"
  run /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" \
    || die "homebrew install failed"
  load_brew || die "homebrew installed but not found on PATH"
}

# brew_install_each <manifest> — install one at a time so a single bad formula
# does not abort the whole run.
brew_install_each() {
  local manifest="$1" pkg
  while IFS= read -r pkg; do
    [[ -n "$pkg" ]] || continue
    if brew list --formula "${pkg##*/}" >/dev/null 2>&1; then
      skip "$pkg (already installed)"
      continue
    fi
    log "brew install $pkg"
    run brew install "$pkg" || warn "brew install $pkg failed — continuing"
  done < <(read_manifest "$manifest")
}
