#!/usr/bin/env bash
# Language runtimes and the tools installed through them.
#
# Runs after the OS package pass. Everything here is identical on macOS and
# Linux, which is the point: the language-level toolchain is the part of the
# environment that should not vary by platform at all.
set -uo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

load_brew || true

# Per-user install dirs. A non-interactive script does not read the shell
# config, so without these every `has bun` / `has pipx` check misses an
# existing install and reinstalls it on each run.
for _d in "$HOME/.local/bin" "$HOME/.bun/bin" "$HOME/.deno/bin" "$HOME/.cargo/bin" "$HOME/go/bin"; do
  [[ -d "$_d" ]] && export PATH="$_d:$PATH"
done
unset _d
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

  # Neither installer may edit ~/.zshrc / ~/.bashrc — they are stowed from this
  # repo, which already puts ~/.bun/bin and ~/.deno/bin on PATH. bun only edits
  # the rc file of a shell it recognises, so it gets SHELL=sh; deno has a flag.
  if has bun; then ok "bun already installed"; else
    log "installing bun"
    run env SHELL=/bin/sh bash -c "curl -fsSL https://bun.sh/install | bash" || warn "bun install failed"
  fi
  if has deno; then ok "deno already installed"; else
    log "installing deno"
    # -y: no "edit shell config?" prompt, which would block an unattended run.
    run sh -c "curl -fsSL https://deno.land/install.sh | sh -s -- -y --no-modify-path" || warn "deno install failed"
  fi
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
  install_go_versions
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
}

# GVM carries the older Go lines that legacy services still build against.
# It uses binary releases, so it does not depend on the system `go`.
install_go_versions() {
  export GVM_ROOT="$HOME/.gvm"
  if [[ ! -s "$GVM_ROOT/scripts/gvm" ]]; then
    log "installing gvm"
    # GVM_NO_UPDATE_PROFILE: the installer must not append to ~/.zshrc /
    # ~/.bashrc, which are stowed from this repo; tools.zsh already loads GVM.
    run env GVM_NO_UPDATE_PROFILE=1 bash -c \
      "curl -fsSL https://raw.githubusercontent.com/moovweb/gvm/master/binscripts/gvm-installer | bash" \
      || { warn "gvm install failed"; return 0; }
  fi
  [[ -s "$GVM_ROOT/scripts/gvm" ]] || return 0

  # Without environments/system, GVM's zsh startup falls back to a broken
  # version lookup and prints "Invalid or corrupt Go version" on every shell.
  if [[ ! -f "$GVM_ROOT/environments/system" ]]; then
    mkdir -p "$GVM_ROOT/environments"
    printf '%s\n' \
      "export GVM_ROOT; GVM_ROOT=\"$GVM_ROOT\"" \
      'export gvm_go_name; gvm_go_name="system"' \
      'export gvm_pkgset_name; gvm_pkgset_name=""' \
      > "$GVM_ROOT/environments/system"
  fi

  local v
  for v in $GO_VERSIONS; do
    if [[ -d "$GVM_ROOT/gos/go$v" ]]; then
      ok "gvm go$v already installed"
      continue
    fi
    log "gvm install go$v"
    # -B fetches the official binary release, so no bootstrap Go toolchain is needed.
    run bash -c 'source "$GVM_ROOT/scripts/gvm" && gvm install "go$1" -B' _ "$v" \
      || warn "gvm install go$v failed"
  done
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
  # macOS ships Ruby 2.6, too old for current cocoapods/rubocop. load_brew puts
  # Homebrew's ruby first when it is installed; say so when it is not.
  local ruby_major
  ruby_major="$(ruby -e 'print RUBY_VERSION.split(".").first' 2>/dev/null || echo 0)"
  (( ruby_major >= 3 )) || warn "using ruby $(ruby -e 'print RUBY_VERSION' 2>/dev/null) from $(command -v ruby) — some gems need ruby >= 3 (brew install ruby)"

  local g other
  while IFS= read -r g; do
    if gem list -i "^${g}\$" >/dev/null 2>&1; then
      skip "$g (gem already installed)"
      continue
    fi
    # Same tool already installed another way (e.g. fastlane from Homebrew):
    # leave both alone and let the user pick, rather than installing a copy
    # that shadows the other on PATH.
    other="$(command -v "$g" 2>/dev/null || true)"
    if [[ -n "$other" ]]; then
      warn "$g is already installed at $other — skipping the gem (remove one to avoid two copies)"
      continue
    fi
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

  # SDKMAN! needs Bash 4+, and macOS's /bin/bash is 3.2. Every SDKMAN step
  # runs in a modern bash subprocess instead of this script's own shell.
  local sdk_bash= candidate
  for candidate in /opt/homebrew/bin/bash /usr/local/bin/bash /home/linuxbrew/.linuxbrew/bin/bash "$(command -v bash)"; do
    [[ -x "$candidate" ]] || continue
    if "$candidate" -c '(( BASH_VERSINFO[0] >= 4 ))' 2>/dev/null; then
      sdk_bash="$candidate"; break
    fi
  done
  [[ -n "$sdk_bash" ]] || { warn "sdkman needs bash >= 4 (brew install bash)"; return 0; }

  if [[ ! -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]]; then
    log "installing sdkman (with $sdk_bash)"
    # rcupdate=false: the installer must not append to ~/.zshrc / ~/.bashrc,
    # which are stowed from this repo; zsh/zshrc.d/tools.zsh already loads SDKMAN!.
    run "$sdk_bash" -c "curl -fsSL 'https://get.sdkman.io?rcupdate=false' | '$sdk_bash'" \
      || { warn "sdkman install failed"; return 0; }
  fi
  [[ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]] || return 0
  log "sdk install java $JAVA_VERSION"
  run "$sdk_bash" -c 'source "$SDKMAN_DIR/bin/sdkman-init.sh" && sdkman_auto_answer=true sdk install java "$1"' \
    _ "$JAVA_VERSION" || warn "sdk install java $JAVA_VERSION failed"
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
