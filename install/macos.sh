#!/usr/bin/env bash
# macOS package installation: Xcode CLT + Homebrew + Brewfile.
set -uo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

install_xcode_clt() {
  if xcode-select -p >/dev/null 2>&1; then
    ok "xcode command line tools present"
    return 0
  fi
  log "installing xcode command line tools"
  run xcode-select --install || true
  # xcode-select --install returns immediately; the GUI installer runs async.
  warn "finish the Xcode CLT installer window, then re-run this script"
  exit 1
}

main() {
  install_xcode_clt
  install_brew

  log "updating homebrew"
  run brew update || warn "brew update failed — continuing with the current index"

  log "installing from packages/Brewfile"
  # `|| true`: brew bundle exits non-zero if any single entry fails (a cask
  # needing a password, an unavailable formula). The rest still installs, and
  # the check below reports exactly what is missing.
  run brew bundle --file="$DOTFILES_DIR/packages/Brewfile" --no-lock || true

  log "verifying Brewfile"
  if brew bundle check --file="$DOTFILES_DIR/packages/Brewfile" >/dev/null 2>&1; then
    ok "every Brewfile entry is installed"
  else
    warn "some Brewfile entries are missing:"
    brew bundle check --file="$DOTFILES_DIR/packages/Brewfile" --verbose 2>&1 | sed 's/^/     /'
  fi

  ok "macOS packages done"
}

main "$@"
