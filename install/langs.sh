#!/usr/bin/env bash
# Language runtimes and the tools installed through them.
#
# Runs after the OS package pass. Everything here is identical on macOS and
# Linux, which is the point: the language-level toolchain is the part of the
# environment that should not vary by platform at all.
set -uo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

load_brew || true
# shellcheck disable=SC1091
source "$DOTFILES_DIR/packages/runtimes.env"

# ---------------------------------------------------------------------------
# Node — nvm
# ---------------------------------------------------------------------------

install_node() {
  export NVM_DIR="$HOME/.nvm"
  if [[ ! -s "$NVM_DIR/nvm.sh" ]]; then
    log "installing nvm"
    run bash -c "curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash" \
      || { warn "nvm install failed"; return 0; }
  fi
  [[ -s "$NVM_DIR/nvm.sh" ]] || return 0
  # shellcheck disable=SC1091
  source "$NVM_DIR/nvm.sh"

  local first= v
  for v in $NODE_VERSIONS; do
    log "nvm install $v"
    run nvm install "$v" || warn "nvm install $v failed"
    [[ -n "$first" ]] || first="$v"
  done
  [[ -n "$first" ]] && run nvm alias default "$first"

  if has npm; then
    local pkg
    while IFS= read -r pkg; do
      log "npm install -g $pkg"
      run npm install -g "$pkg" || warn "npm install -g $pkg failed"
    done < <(read_manifest "$DOTFILES_DIR/packages/npm.txt")
  fi

  has bun  || { log "installing bun";  run bash -c "curl -fsSL https://bun.sh/install | bash" || warn "bun install failed"; }
  has deno || { log "installing deno"; run bash -c "curl -fsSL https://deno.land/install.sh | sh" || warn "deno install failed"; }
}

# ---------------------------------------------------------------------------
# Python — pyenv + pipx
# ---------------------------------------------------------------------------

install_python() {
  export PYENV_ROOT="$HOME/.pyenv"
  if ! has pyenv && [[ ! -d "$PYENV_ROOT" ]]; then
    log "installing pyenv"
    run bash -c "curl -fsSL https://pyenv.run | bash" || warn "pyenv install failed"
  fi
  [[ -d "$PYENV_ROOT/bin" ]] && export PATH="$PYENV_ROOT/bin:$PATH"

  if has pyenv; then
    eval "$(pyenv init -)" || true
    local first= v
    for v in $PYTHON_VERSIONS; do
      if pyenv versions --bare 2>/dev/null | grep -qx "$v"; then
        skip "python $v (already installed)"
      else
        log "pyenv install $v"
        run pyenv install -s "$v" || warn "pyenv install $v failed"
      fi
      [[ -n "$first" ]] || first="$v"
    done
    [[ -n "$first" ]] && run pyenv global "$first"
  fi

  if ! has pipx; then
    log "installing pipx"
    run python3 -m pip install --user --break-system-packages pipx 2>/dev/null \
      || run python3 -m pip install --user pipx \
      || warn "pipx install failed"
  fi
  has pipx || return 0

  local pkg
  while IFS= read -r pkg; do
    log "pipx install $pkg"
    run pipx install "$pkg" || warn "pipx install $pkg failed"
  done < <(read_manifest "$DOTFILES_DIR/packages/pipx.txt")
}

# ---------------------------------------------------------------------------
# Go
# ---------------------------------------------------------------------------

install_go() {
  if ! has go; then
    warn "go is not installed — run the OS package pass first; skipping go tools"
    return 0
  fi
  export GOPATH="${GOPATH:-$HOME/go}"
  export PATH="$GOPATH/bin:$PATH"

  local pkg
  while IFS= read -r pkg; do
    log "go install $pkg"
    run go install "$pkg" || warn "go install $pkg failed"
  done < <(read_manifest "$DOTFILES_DIR/packages/go.txt")

  # vfox carries the older Go lines that legacy services still build against.
  if has vfox; then
    vfox list 2>/dev/null | grep -q golang || run vfox add golang || true
    local v
    for v in $GO_VERSIONS; do
      log "vfox install golang@$v"
      run vfox install "golang@$v" || warn "vfox install golang@$v failed"
    done
  fi
}

# ---------------------------------------------------------------------------
# Rust — rustup
# ---------------------------------------------------------------------------

install_rust() {
  # rustup lives in ~/.cargo/bin, which a non-login shell may not have on PATH.
  # Source the env first so an existing install is not reinstalled over itself.
  [[ -f "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"
  if ! has rustup; then
    log "installing rustup"
    run bash -c "curl --proto '=https' --tlsv1.2 -fsSL https://sh.rustup.rs | sh -s -- -y --no-modify-path" \
      || { warn "rustup install failed"; return 0; }
  fi
  [[ -f "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"
  has cargo || return 0

  run rustup component add rust-analyzer clippy rustfmt || warn "rustup component add failed"

  local crate
  while IFS= read -r crate; do
    log "cargo install $crate"
    run cargo install "$crate" || warn "cargo install $crate failed"
  done < <(read_manifest "$DOTFILES_DIR/packages/cargo.txt")
}

# ---------------------------------------------------------------------------
# Ruby
# ---------------------------------------------------------------------------

install_ruby() {
  if ! has gem; then
    warn "ruby is not installed — skipping gems"
    return 0
  fi
  local g
  while IFS= read -r g; do
    log "gem install $g"
    # --user-install keeps this out of the system gem dir, so no sudo is needed.
    run gem install --user-install "$g" || warn "gem install $g failed"
  done < <(read_manifest "$DOTFILES_DIR/packages/gem.txt")
}

# ---------------------------------------------------------------------------
# Java — SDKMAN!
# ---------------------------------------------------------------------------

install_java() {
  [[ -n "${JAVA_VERSION:-}" ]] || { skip "java (no version pinned)"; return 0; }
  export SDKMAN_DIR="$HOME/.sdkman"
  if [[ ! -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]]; then
    log "installing sdkman"
    run bash -c "curl -fsSL https://get.sdkman.io | bash" || { warn "sdkman install failed"; return 0; }
  fi
  [[ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]] || return 0
  # shellcheck disable=SC1091
  source "$SDKMAN_DIR/bin/sdkman-init.sh"
  log "sdk install java $JAVA_VERSION"
  run sdk install java "$JAVA_VERSION" || warn "sdk install java $JAVA_VERSION failed"
}

main() {
  local targets=("${@:-}")
  if [[ -z "${targets[0]:-}" ]]; then
    targets=(node python go rust ruby java)
  fi
  local t
  for t in "${targets[@]}"; do
    case "$t" in
      node)   install_node ;;
      python) install_python ;;
      go)     install_go ;;
      rust)   install_rust ;;
      ruby)   install_ruby ;;
      java)   install_java ;;
      *)      warn "unknown language target: $t" ;;
    esac
  done
  ok "language toolchains done"
}

main "$@"
