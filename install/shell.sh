#!/usr/bin/env bash
# Shell environment: oh-my-zsh, its custom plugins, and fzf key bindings.
set -uo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

load_brew || true

ZSH_DIR="${ZSH:-$HOME/.oh-my-zsh}"
ZSH_CUSTOM="${ZSH_CUSTOM:-$ZSH_DIR/custom}"

install_omz() {
  if [[ -d "$ZSH_DIR" ]]; then
    ok "oh-my-zsh already installed"
    return 0
  fi
  log "installing oh-my-zsh"
  # RUNZSH=no stops the installer from dropping us into a subshell mid-script;
  # KEEP_ZSHRC=yes stops it from clobbering the ~/.zshrc that stow just linked.
  run bash -c 'RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"' \
    || warn "oh-my-zsh install failed"
}

install_omz_plugins() {
  local name url dest
  while read -r name url; do
    [[ -n "$name" ]] || continue
    dest="$ZSH_CUSTOM/plugins/$name"
    if [[ -d "$dest" ]]; then
      skip "$name (already cloned)"
      continue
    fi
    log "cloning $name"
    run git clone --depth=1 "$url" "$dest" || warn "clone $name failed"
  done <<'PLUGINS'
zsh-autosuggestions https://github.com/zsh-users/zsh-autosuggestions
zsh-syntax-highlighting https://github.com/zsh-users/zsh-syntax-highlighting
PLUGINS
}

install_fzf_bindings() {
  has fzf || { warn "fzf not installed — skipping key bindings"; return 0; }
  [[ -f "$HOME/.fzf.zsh" ]] && { ok "fzf key bindings present"; return 0; }

  local fzf_base
  fzf_base="$(brew --prefix fzf 2>/dev/null || echo /usr/share/fzf)"
  if [[ -x "$fzf_base/install" ]]; then
    log "installing fzf key bindings"
    run "$fzf_base/install" --key-bindings --completion --no-update-rc || warn "fzf install failed"
  else
    warn "fzf install script not found under $fzf_base — set up key bindings manually"
  fi
}

set_default_shell() {
  has zsh || { warn "zsh not installed — cannot set the default shell"; return 0; }
  local zsh_path
  zsh_path="$(command -v zsh)"
  if [[ "${SHELL:-}" == "$zsh_path" ]]; then
    ok "zsh is already the default shell"
    return 0
  fi
  # chsh only accepts shells listed in /etc/shells.
  if ! grep -qxF "$zsh_path" /etc/shells 2>/dev/null; then
    log "registering $zsh_path in /etc/shells"
    init_sudo
    run bash -c "echo '$zsh_path' | $SUDO tee -a /etc/shells >/dev/null" || true
  fi
  log "setting zsh as the default shell"
  run chsh -s "$zsh_path" || warn "chsh failed — change your login shell manually"
}

install_yazi_packages() {
  has yazi || { skip "yazi (not installed)"; return 0; }
  [[ -f "$HOME/.config/yazi/package.toml" ]] || { skip "yazi (no package.toml — run stow first)"; return 0; }
  # package.toml pins each plugin and flavor by revision and hash, so the
  # vendored trees under plugins/ and flavors/ never need to be committed.
  log "restoring yazi plugins and flavors"
  run ya pkg install || warn "ya pkg install failed"
}

main() {
  install_omz
  install_omz_plugins
  install_fzf_bindings
  install_yazi_packages
  set_default_shell
  ok "shell environment done"
}

main "$@"
