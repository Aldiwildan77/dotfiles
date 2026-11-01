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

# Put brew on PATH (fresh shells, CI) and in FRONT of the system dirs, even when
# it is already on PATH: otherwise /usr/bin/ruby (2.6 on macOS), /bin/bash (3.2)
# and friends shadow the Homebrew versions the later stages rely on.
load_brew() {
  local candidate brew_bin=
  if has brew; then
    brew_bin="$(command -v brew)"
  else
    for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew \
                     /home/linuxbrew/.linuxbrew/bin/brew "$HOME/.linuxbrew/bin/brew"; do
      [[ -x "$candidate" ]] && { brew_bin="$candidate"; break; }
    done
  fi
  [[ -n "$brew_bin" ]] || return 1
  eval "$("$brew_bin" shellenv)"
  local prefix="${HOMEBREW_PREFIX:-$(dirname "$(dirname "$brew_bin")")}"
  export PATH="$prefix/bin:$prefix/sbin:$PATH"
}

# Returns non-zero on failure rather than exiting: on Linux Homebrew is optional,
# and a failed install must not stop the native/vendor passes. Callers that
# cannot continue without brew (macOS) decide to die themselves.
install_brew() {
  load_brew && { ok "homebrew already installed"; return 0; }
  log "installing homebrew"
  run /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" \
    || { err "homebrew install failed"; return 1; }
  [[ "$DRY_RUN" == "1" ]] && return 0
  load_brew || { err "homebrew installed but not found on PATH"; return 1; }
}

# brew_install_each <manifest> — install one at a time so a single bad formula
# does not abort the whole run.
#
# warn_untrusted_taps <tap ...> — Homebrew refuses formulae from third-party taps
# until they are trusted with `brew trust`. Trusting is a deliberate per-machine
# decision, so this only reports the commands to run; it never trusts anything.
warn_untrusted_taps() {
  local trusted tap missing=()
  # Older Homebrew has no `brew trust` and loads every tap, so nothing to do.
  trusted="$(brew trust --json=v1 2>/dev/null)" || return 0
  for tap in "$@"; do
    grep -q "\"$tap[\"/]" <<<"$trusted" || missing+=("$tap")
  done
  [[ ${#missing[@]} -gt 0 ]] || return 0
  warn "untrusted third-party taps — their formulae will fail to install:"
  for tap in "${missing[@]}"; do
    warn "    brew trust --tap $tap"
  done
  warn "run those, then re-run this stage"
}

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
