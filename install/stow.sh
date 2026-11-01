#!/usr/bin/env bash
# Symlink the config packages into $HOME with GNU stow.
#
# Every top-level directory listed in STOW_PACKAGES mirrors the layout it should
# have under $HOME, so `stow zsh` makes ~/.zshrc point at zsh/.zshrc here.
set -uo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# Every entry is a top-level directory here whose contents mirror $HOME.
# Packages with a .config/ subtree (yazi, gh, zed) land in ~/.config/<tool>/.
STOW_PACKAGES=(
  zsh bash            # shells
  vim tmux screen     # editors and multiplexers
  git gh              # version control
  yazi zed            # file manager, editor
  editorconfig        # ~/.editorconfig
  dig wget            # cli tool configs
)

# Real files already sitting where a symlink needs to go are moved aside rather
# than deleted — a fresh machine usually has a distro-provided ~/.vimrc.
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

backup_conflicts() {
  local pkg="$1" rel target real_dir repo
  repo="$(cd -P "$DOTFILES_DIR" && pwd -P)"
  while IFS= read -r rel; do
    target="$HOME/${rel#./}"
    # Only real files/dirs conflict. An existing symlink is either already ours
    # or will be replaced by --restow, so leave it to stow.
    [[ -e "$target" && ! -L "$target" ]] || continue
    # A file reached through a stow-folded directory (~/.config/yazi -> repo)
    # IS the repo file. Moving it would delete it from the repo.
    real_dir="$(cd -P "$(dirname "$target")" 2>/dev/null && pwd -P)"
    [[ "$real_dir/" == "$repo/"* ]] && continue
    log "backing up $target"
    run mkdir -p "$BACKUP_DIR/$(dirname "${rel#./}")"
    run mv "$target" "$BACKUP_DIR/${rel#./}"
  done < <(cd "$DOTFILES_DIR/$pkg" && find . -type f | sed 's|^\./||' | sed 's|^|./|')
}

# stow is the only hard dependency of this stage, so install just that when the
# full `packages` pass has not run — `./setup.sh stow` works on its own.
ensure_stow() {
  load_brew || true
  has stow && return 0
  log "stow is missing — installing it"
  if [[ "$OS" == "macos" ]]; then
    load_brew || install_brew || return 1
    run brew install stow || return 1
  else
    detect_pkg_mgr
    init_sudo
    case "$PKG_MGR" in
      apt)    run $SUDO apt-get update -qq && run $SUDO apt-get install -y stow ;;
      dnf)    run $SUDO dnf install -y stow ;;
      pacman) run $SUDO pacman -S --needed --noconfirm stow ;;
      zypper) run $SUDO zypper --non-interactive install stow ;;
      apk)    run $SUDO apk add stow ;;
      *)      has brew && run brew install stow ;;
    esac || return 1
  fi
  [[ "$DRY_RUN" == "1" ]] || has stow
}

main() {
  detect_os
  ensure_stow || die "could not install stow — run ./setup.sh packages first"

  local pkg
  for pkg in "${STOW_PACKAGES[@]}"; do
    if [[ ! -d "$DOTFILES_DIR/$pkg" ]]; then
      warn "no such stow package: $pkg"
      continue
    fi
    backup_conflicts "$pkg"
    log "stow $pkg"
    run stow --dir="$DOTFILES_DIR" --target="$HOME" --restow "$pkg" \
      || warn "stow $pkg failed"
  done

  [[ -d "$BACKUP_DIR" ]] && warn "displaced files were moved to $BACKUP_DIR"
  ok "dotfiles linked"
}

main "$@"
