#!/usr/bin/env bash
# Compare what this repo declares against what the machine actually has.
#
#   ./install/doctor.sh          # summary
#   ./install/doctor.sh -v       # list every tool, present or not
#
# Exit code is the number of missing tools, so CI can gate on it.
set -uo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

detect_os
detect_arch
load_brew || true

# These live outside the default PATH of a non-login shell, so pull them in
# before checking — otherwise doctor reports installed tools as missing.
[[ -f "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"
[[ -d "${GOPATH:-$HOME/go}/bin" ]] && PATH="${GOPATH:-$HOME/go}/bin:$PATH"
[[ -d "$HOME/.local/bin" ]] && PATH="$HOME/.local/bin:$PATH"
[[ -d "$HOME/.bun/bin" ]] && PATH="$HOME/.bun/bin:$PATH"
export PATH

VERBOSE=0
[[ "${1:-}" == "-v" || "${1:-}" == "--verbose" ]] && VERBOSE=1

MISSING=()
PRESENT=0

# check <command> [note] — record whether a command resolves on PATH.
check() {
  local cmd="$1" note="${2:-}"
  if has "$cmd"; then
    PRESENT=$((PRESENT + 1))
    [[ $VERBOSE -eq 1 ]] && ok "$cmd"
  else
    MISSING+=("$cmd${note:+ ($note)}")
    [[ $VERBOSE -eq 1 ]] && warn "$cmd missing${note:+ — $note}"
  fi
}

section() { printf '\n%s-- %s%s\n' "$_C_BLUE" "$1" "$_C_RESET"; }

section "core"
for c in zsh git stow curl wget jq yq tree rsync gpg; do check "$c"; done
check rg "ripgrep"
if ! has bat && has batcat; then PRESENT=$((PRESENT + 1)); else check bat; fi
check fzf
check yazi

section "version control"
for c in gh git-lfs; do check "$c"; done

section "languages"
for c in go node npm python3 pip3 ruby gem php composer; do check "$c"; done
check cargo "rustup"
check bun
check deno
check java

section "version managers"
for c in pyenv vfox; do check "$c"; done
[[ -s "$HOME/.nvm/nvm.sh" ]] && PRESENT=$((PRESENT + 1)) || MISSING+=("nvm")
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && PRESENT=$((PRESENT + 1)) || MISSING+=("sdkman")

section "backend / data"
for c in mysql psql redis-cli sqlite3 protoc migrate temporal; do check "$c"; done

section "infrastructure"
for c in docker kubectl helm k9s stern kubectx terraform ansible aws gcloud flyctl sops age mkcert; do
  check "$c"
done

section "go tools"
for c in gopls goimports dlv golangci-lint; do check "$c"; done

section "media"
for c in ffmpeg dot vips yt-dlp; do check "$c"; done

# ---------------------------------------------------------------------------
# Dotfile links
# ---------------------------------------------------------------------------
section "dotfile links"
for f in .zshrc .bashrc .bash_profile .vimrc .tmux.conf .gitconfig .gitignore_global \
         .editorconfig .screenrc .digrc .wgetrc \
         .config/yazi/yazi.toml .config/gh/config.yml .config/zed/settings.json; do
  if [[ -L "$HOME/$f" ]]; then
    [[ $VERBOSE -eq 1 ]] && ok "~/$f -> $(readlink "$HOME/$f")"
    PRESENT=$((PRESENT + 1))
  elif [[ -e "$HOME/$f" ]]; then
    warn "~/$f exists but is not a symlink — run './setup.sh stow'"
    MISSING+=("~/$f (not stowed)")
  else
    MISSING+=("~/$f (absent)")
  fi
done

# ---------------------------------------------------------------------------
# Homebrew drift — declared vs installed
# ---------------------------------------------------------------------------
if has brew && [[ "$OS" == "macos" ]]; then
  section "homebrew drift"
  # Both sides are normalised to the bare formula name: `brew leaves` prints
  # tapped formulae as owner/tap/name, while the Brewfile may spell the same
  # entry either way.
  undeclared="$(comm -23 \
    <(brew leaves | sed 's|.*/||' | sort -u) \
    <(read_manifest "$DOTFILES_DIR/packages/Brewfile" \
        | grep -oE '^brew "[^"]+"' | sed 's/brew "//;s/"//;s|.*/||' | sort -u) \
    2>/dev/null)"
  if [[ -n "$undeclared" ]]; then
    warn "installed but not in Brewfile (run install/export.sh to capture):"
    echo "$undeclared" | sed 's/^/     /'
  else
    ok "Brewfile covers every top-level formula"
  fi
fi

# ---------------------------------------------------------------------------
# Secret guard
#
# Stowing gh, yazi and zed points ~/.config/<tool> at a directory inside this
# repo, so those tools write their runtime state here — including gh's OAuth
# token in hosts.yml. .gitignore covers every known case; this check catches a
# path that slipped through before it reaches a commit.
# ---------------------------------------------------------------------------
section "secret guard"
if git -C "$DOTFILES_DIR" rev-parse --git-dir >/dev/null 2>&1; then
  leaked=0
  for pattern in 'gh/.config/gh/hosts.yml' 'gh/.config/gh/state.yml' \
                 '*.zshrc.local' '*.gitconfig.work' '*.pem' '*.key'; do
    tracked="$(git -C "$DOTFILES_DIR" ls-files "$pattern" 2>/dev/null)"
    if [[ -n "$tracked" ]]; then
      err "TRACKED SECRET: $tracked"
      leaked=1
    fi
  done
  # Company profiles belong in ~/.zshrc.d, never here.
  if [[ -n "$(git -C "$DOTFILES_DIR" ls-files 'zsh/zshrc.d/*/*' 2>/dev/null)" ]]; then
    err "TRACKED COMPANY PROFILE under zsh/zshrc.d/ — move it to ~/.zshrc.d/"
    git -C "$DOTFILES_DIR" ls-files 'zsh/zshrc.d/*/*' | sed 's/^/     /'
    leaked=1
  fi

  # Catch tokens pasted into any tracked file, whatever it is called.
  if git -C "$DOTFILES_DIR" grep -lIE 'gh[pousr]_[A-Za-z0-9]{16,}|AKIA[0-9A-Z]{16}|BEGIN [A-Z ]*PRIVATE KEY' \
       -- . >/dev/null 2>&1; then
    err "TRACKED SECRET: credential pattern found in a tracked file"
    git -C "$DOTFILES_DIR" grep -lIE 'gh[pousr]_[A-Za-z0-9]{16,}|AKIA[0-9A-Z]{16}|BEGIN [A-Z ]*PRIVATE KEY' -- . | sed 's/^/     /'
    leaked=1
  fi
  if [[ $leaked -eq 0 ]]; then
    ok "no secrets tracked"
  else
    MISSING+=("SECRET LEAK — see above, do not push")
  fi
else
  skip "secret guard (not a git checkout)"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf '\n'
if [[ ${#MISSING[@]} -eq 0 ]]; then
  ok "$PRESENT checks passed, nothing missing"
  exit 0
fi

warn "${#MISSING[@]} missing, $PRESENT present"
printf '%s\n' "${MISSING[@]}" | sed 's/^/     /'
printf '\nrun ./setup.sh to install what is missing\n'
exit "${#MISSING[@]}"
