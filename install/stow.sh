#!/usr/bin/env bash
# Symlink the config packages into $HOME with GNU stow.
#
# Every top-level directory listed in STOW_PACKAGES mirrors the layout it should
# have under $HOME, so `stow zsh` makes ~/.zshrc point at zsh/.zshrc here.
set -uo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

STOW_PACKAGES=(zsh vim git screen dig wget)

# Real files already sitting where a symlink needs to go are moved aside rather
# than deleted — a fresh machine usually has a distro-provided ~/.vimrc.
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

backup_conflicts() {
  local pkg="$1" rel target
  while IFS= read -r rel; do
    target="$HOME/${rel#./}"
    # Only real files/dirs conflict. An existing symlink is either already ours
    # or will be replaced by --restow, so leave it to stow.
    if [[ -e "$target" && ! -L "$target" ]]; then
      log "backing up $target"
      run mkdir -p "$BACKUP_DIR/$(dirname "${rel#./}")"
      run mv "$target" "$BACKUP_DIR/${rel#./}"
    fi
  done < <(cd "$DOTFILES_DIR/$pkg" && find . -type f | sed 's|^\./||' | sed 's|^|./|')
}

main() {
  has stow || die "stow is not installed — run the OS package pass first"

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
