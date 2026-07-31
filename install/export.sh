#!/usr/bin/env bash
# Snapshot what this machine has into packages/*.local files.
#
#   ./install/export.sh
#
# The output is deliberately written to `.local` siblings rather than over the
# curated manifests: a raw dump includes machine-specific noise (one-off casks,
# transitive gems, work tooling) that should not land in the repo unreviewed.
# Diff the pair, fold in what belongs, discard the rest.
#
#   diff packages/Brewfile packages/Brewfile.local
set -uo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

detect_os
load_brew || true

OUT="$DOTFILES_DIR/packages"

export_brew() {
  has brew || { skip "brew (not installed)"; return 0; }
  log "dumping Brewfile.local"
  run brew bundle dump --force --describe --file="$OUT/Brewfile.local"
  ok "$OUT/Brewfile.local"
}

export_go() {
  [[ -d "${GOPATH:-$HOME/go}/bin" ]] || { skip "go (no GOPATH/bin)"; return 0; }
  log "listing go binaries"
  {
    echo "# Snapshot of \$GOPATH/bin — binary names only."
    echo "# Look each up and record the full module path in packages/go.txt."
    ls -1 "${GOPATH:-$HOME/go}/bin"
  } > "$OUT/go.txt.local"
  ok "$OUT/go.txt.local"
}

export_npm() {
  has npm || { skip "npm (not installed)"; return 0; }
  log "listing global npm packages"
  npm ls -g --depth=0 --parseable 2>/dev/null \
    | tail -n +2 | sed 's|.*/||' > "$OUT/npm.txt.local"
  ok "$OUT/npm.txt.local"
}

export_cargo() {
  has cargo || { skip "cargo (not installed)"; return 0; }
  log "listing cargo binaries"
  cargo install --list 2>/dev/null \
    | grep -E '^[a-zA-Z0-9_-]+ v' | awk '{print $1}' > "$OUT/cargo.txt.local"
  ok "$OUT/cargo.txt.local"
}

export_pipx() {
  has pipx || { skip "pipx (not installed)"; return 0; }
  log "listing pipx apps"
  pipx list --short 2>/dev/null | awk '{print $1}' > "$OUT/pipx.txt.local"
  ok "$OUT/pipx.txt.local"
}

export_gem() {
  has gem || { skip "gem (not installed)"; return 0; }
  log "listing gems"
  {
    echo "# Raw gem list — most entries are transitive dependencies."
    echo "# Only top-level tools belong in packages/gem.txt."
    gem list --no-versions 2>/dev/null
  } > "$OUT/gem.txt.local"
  ok "$OUT/gem.txt.local"
}

export_apt() {
  has apt-mark || { skip "apt (not a Debian machine)"; return 0; }
  log "listing manually-installed apt packages"
  apt-mark showmanual > "$OUT/linux/apt.txt.local"
  ok "$OUT/linux/apt.txt.local"
}

export_runtimes() {
  log "recording runtime versions"
  {
    echo "# Versions present on $(hostname) at $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    for t in go node bun deno python3 ruby php java rustc docker kubectl terraform ansible; do
      if has "$t"; then
        printf '%-10s %s\n' "$t" "$("$t" --version 2>&1 | head -1)"
      fi
    done
  } > "$OUT/runtimes.local"
  ok "$OUT/runtimes.local"
}

main() {
  mkdir -p "$OUT/linux"
  export_brew
  export_go
  export_npm
  export_cargo
  export_pipx
  export_gem
  export_apt
  export_runtimes
  printf '\n'
  ok "snapshot written — diff against the curated manifests before committing"
  warn "*.local files are gitignored on purpose; fold changes in by hand"
}

main "$@"
