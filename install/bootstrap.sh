#!/usr/bin/env bash
# Entry point for provisioning a machine from this repo.
#
#   ./install/bootstrap.sh              # everything
#   ./install/bootstrap.sh packages     # OS packages only
#   ./install/bootstrap.sh langs stow   # a specific subset, in the given order
#   DRY_RUN=1 ./install/bootstrap.sh    # print the plan, change nothing
set -uo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

detect_os
detect_arch

STAGES=(packages langs stow shell)

usage() {
  cat <<EOF
usage: $(basename "$0") [stage ...]

stages:
  packages   OS package manager pass (brew / apt / dnf / pacman)
  langs      language runtimes and their global tools
  stow       symlink the dotfiles into \$HOME
  shell      oh-my-zsh, plugins, fzf bindings, default shell

env:
  DRY_RUN=1     print what would happen, change nothing
  SKIP_BREW=1   Linux only: skip the Homebrew parity set

with no arguments every stage runs, in the order listed above.
EOF
}

# Stage scripts are invoked directly rather than through run(): each one honours
# DRY_RUN itself, so this way a dry run prints the real per-package plan instead
# of a single "would run install/macos.sh" line.
stage_packages() {
  case "$OS" in
    macos) bash "$DOTFILES_DIR/install/macos.sh" ;;
    linux) bash "$DOTFILES_DIR/install/linux.sh" ;;
    windows)
      err "run install/windows.ps1 from PowerShell instead, or use WSL2 and re-run this script there"
      return 1 ;;
    *) die "unsupported OS: ${OSTYPE:-unknown}" ;;
  esac
}

stage_langs() { bash "$DOTFILES_DIR/install/langs.sh"; }
stage_stow()  { bash "$DOTFILES_DIR/install/stow.sh"; }
stage_shell() { bash "$DOTFILES_DIR/install/shell.sh"; }

main() {
  case "${1:-}" in
    -h|--help|help) usage; exit 0 ;;
  esac

  local requested=("$@")
  [[ ${#requested[@]} -gt 0 ]] || requested=("${STAGES[@]}")

  log "dotfiles bootstrap — os=$OS arch=$ARCH repo=$DOTFILES_DIR"
  [[ "$DRY_RUN" == "1" ]] && warn "DRY_RUN=1 — nothing will be modified"

  # The zsh config resolves everything relative to $HOME/dotfiles. Working from
  # a clone somewhere else is fine, but the shell will not find its config.
  if [[ "$DOTFILES_DIR" != "$HOME/dotfiles" ]]; then
    warn "repo is at $DOTFILES_DIR, not \$HOME/dotfiles"
    warn "either clone it there or export DOTFILES_DIR=$DOTFILES_DIR in your shell"
  fi

  local stage failed=0
  for stage in "${requested[@]}"; do
    case "$stage" in
      packages|langs|stow|shell)
        log "stage: $stage"
        "stage_$stage" || { err "stage $stage failed"; failed=1; }
        ;;
      *) err "unknown stage: $stage"; usage; exit 1 ;;
    esac
  done

  if [[ $failed -eq 0 ]]; then
    ok "bootstrap complete — open a new shell to pick up the changes"
  else
    warn "bootstrap finished with errors — see the log above"
    exit 1
  fi
}

main "$@"
