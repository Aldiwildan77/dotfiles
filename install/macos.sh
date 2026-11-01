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

# Homebrew's docker-compose / docker-buildx are CLI plugins: `docker compose`
# only finds them if ~/.docker/config.json lists brew's plugin dir. Merge that
# one key in, leaving registry auth and contexts untouched.
configure_docker_plugins() {
  has docker || return 0
  local plugin_dir cfg="$HOME/.docker/config.json"
  plugin_dir="$(brew --prefix)/lib/docker/cli-plugins"
  if [[ -f "$cfg" ]] && grep -q "$plugin_dir" "$cfg"; then
    ok "docker cli plugins already configured"
    return 0
  fi
  log "adding $plugin_dir to $cfg"
  run mkdir -p "$HOME/.docker"
  run python3 -I -c '
import json, os, sys
cfg, d = sys.argv[1], sys.argv[2]
data = json.load(open(cfg)) if os.path.exists(cfg) and os.path.getsize(cfg) else {}
dirs = data.setdefault("cliPluginsExtraDirs", [])
if d not in dirs:
    dirs.append(d)
json.dump(data, open(cfg, "w"), indent=2)
' "$cfg" "$plugin_dir" || warn "could not update $cfg"
}

main() {
  install_xcode_clt
  install_brew || die "homebrew is required on macOS"

  log "updating homebrew"
  run brew update || warn "brew update failed — continuing with the current index"

  # shellcheck disable=SC2046
  warn_untrusted_taps $(sed -n 's/^tap "\([^"]*\)".*/\1/p' "$DOTFILES_DIR/packages/Brewfile")

  log "installing from packages/Brewfile"
  # `|| true`: brew bundle exits non-zero if any single entry fails (a cask
  # needing a password, an unavailable formula). The rest still installs, and
  # the check below reports exactly what is missing.
  run brew bundle --file="$DOTFILES_DIR/packages/Brewfile" || true

  log "verifying Brewfile"
  if brew bundle check --file="$DOTFILES_DIR/packages/Brewfile" >/dev/null 2>&1; then
    ok "every Brewfile entry is installed"
  else
    warn "some Brewfile entries are missing:"
    brew bundle check --file="$DOTFILES_DIR/packages/Brewfile" --verbose 2>&1 | sed 's/^/     /'
  fi

  configure_docker_plugins
  ok "macOS packages done"
}

main "$@"
