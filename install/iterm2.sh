#!/usr/bin/env bash
# iTerm2 preferences: profiles, colours, key bindings and window arrangements.
#
#   ./install/iterm2.sh export   # live prefs -> iterm2/com.googlecode.iterm2.plist
#   ./install/iterm2.sh import   # that file  -> live prefs
#   ./install/iterm2.sh diff     # what would change on export
#
# macOS only. iTerm2 does not use ~/.config — everything lives in a single
# binary plist under ~/Library/Preferences, which is why a plain dotfiles scan
# never finds it, and why this needs its own script rather than a stow package.
#
# Settings only: profiles, colours, fonts, key bindings, global preferences.
# Window arrangements are NOT synced — iTerm2 stores each session's recorded
# shell command history inside them, so a saved layout can carry live
# credentials. See install/iterm2-sanitize.py.
set -uo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

detect_os

LIVE="$HOME/Library/Preferences/com.googlecode.iterm2.plist"
DEST_DIR="$DOTFILES_DIR/iterm2"
DEST="$DEST_DIR/com.googlecode.iterm2.plist"
DOMAIN="com.googlecode.iterm2"
SANITIZER="$DOTFILES_DIR/install/iterm2-sanitize.py"

require_macos() {
  [[ "$OS" == "macos" ]] || die "iTerm2 is macOS only (this is $OS)"
}

# iTerm2 holds preferences in memory and writes them out on quit. Exporting
# while it runs captures whatever was last flushed, which is usually stale.
warn_if_running() {
  if pgrep -x iTerm2 >/dev/null 2>&1; then
    warn "iTerm2 is running — it writes preferences on quit, so this export"
    warn "may be stale. Quit iTerm2 and re-run for an accurate snapshot."
  fi
}

do_export() {
  require_macos
  [[ -f "$LIVE" ]] || die "no preferences at $LIVE — is iTerm2 installed?"
  warn_if_running

  run mkdir -p "$DEST_DIR"
  if [[ "$DRY_RUN" == "1" ]]; then
    printf '%s  would sanitise %s -> %s%s\n' "$_C_DIM" "$LIVE" "$DEST" "$_C_RESET"
    return 0
  fi

  log "sanitising iTerm2 preferences"
  # The sanitiser exits non-zero without writing if a credential survives.
  python3 "$SANITIZER" "$LIVE" "$DEST" || die "export aborted — see above"
  ok "exported. Review the diff before committing:  git diff -- iterm2/"
}

do_import() {
  require_macos
  [[ -f "$DEST" ]] || die "nothing to import — run './install/iterm2.sh export' first"

  if pgrep -x iTerm2 >/dev/null 2>&1; then
    die "quit iTerm2 first — it would overwrite these settings on exit"
  fi

  # Back up whatever is there now; `defaults import` replaces the whole domain.
  if [[ -f "$LIVE" ]]; then
    local backup="$HOME/.dotfiles-backup/iterm2-$(date +%Y%m%d-%H%M%S).plist"
    run mkdir -p "$(dirname "$backup")"
    run cp "$LIVE" "$backup"
    ok "current preferences backed up to $backup"
  fi

  log "importing iTerm2 preferences"
  run defaults import "$DOMAIN" "$DEST" || die "defaults import failed"
  # cfprefsd caches the domain; without this the change is not visible.
  run killall cfprefsd 2>/dev/null || true
  ok "imported — start iTerm2 to pick up the profiles"
  warn "window arrangements are not part of this export; recreate the layout"
  warn "once and save it with Window > Save Window Arrangement"
}

do_diff() {
  require_macos
  [[ -f "$LIVE" ]] || die "no preferences at $LIVE"
  local tmp
  tmp="$(mktemp -t iterm2-export.XXXXXX)"
  python3 "$SANITIZER" "$LIVE" "$tmp" >/dev/null || { rm -f "$tmp"; die "sanitise failed"; }
  if [[ -f "$DEST" ]]; then
    diff -u "$DEST" "$tmp" && ok "no changes since last export"
  else
    warn "no export yet at $DEST"
  fi
  rm -f "$tmp"
}

case "${1:-}" in
  export) do_export ;;
  import) do_import ;;
  diff)   do_diff ;;
  *)
    cat <<EOF
usage: $(basename "$0") {export|import|diff}

  export   live iTerm2 settings -> iterm2/com.googlecode.iterm2.plist
           profiles, colours, fonts, key bindings. Window arrangements and
           per-machine state are excluded.
  import   that file -> live preferences (backs up the current ones first)
  diff     show what an export would change

Quit iTerm2 before either direction — it writes preferences on quit and will
otherwise clobber, or be clobbered by, whatever this does.
EOF
    exit 1 ;;
esac
