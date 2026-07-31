# Version managers and tool initialisation.
#
# Sourced after oh-my-zsh so these PATH edits take precedence over the plugin
# defaults. Every block is guarded, so a machine missing a tool starts clean
# rather than printing errors on every new shell.

# ---------------------------------------------------------------------------
# Node — nvm
# ---------------------------------------------------------------------------
export NVM_DIR="$HOME/.nvm"
if [[ -s "$NVM_DIR/nvm.sh" ]]; then
  source "$NVM_DIR/nvm.sh"
  [[ -s "$NVM_DIR/bash_completion" ]] && source "$NVM_DIR/bash_completion"
elif [[ -s "$HOMEBREW_PREFIX/opt/nvm/nvm.sh" ]]; then
  source "$HOMEBREW_PREFIX/opt/nvm/nvm.sh"
fi

# Bun completions
[[ -s "$BUN_INSTALL/_bun" ]] && source "$BUN_INSTALL/_bun"

# ---------------------------------------------------------------------------
# Python — pyenv
# ---------------------------------------------------------------------------
if command -v pyenv >/dev/null 2>&1; then
  eval "$(pyenv init -)"
  # Only load pyenv-virtualenv when the plugin is actually present.
  if pyenv commands 2>/dev/null | grep -q virtualenv-init; then
    eval "$(pyenv virtualenv-init -)"
  fi
fi

# ---------------------------------------------------------------------------
# Go — vfox handles the legacy Go lines; the default `go` comes from the
# package manager. GVM is deliberately not loaded: its shell scripts are
# bash-only and spew `command not found: _encode` errors under zsh.
# ---------------------------------------------------------------------------
command -v vfox >/dev/null 2>&1 && eval "$(vfox activate zsh)"

# ---------------------------------------------------------------------------
# Rust
# ---------------------------------------------------------------------------
[[ -f "$CARGO_HOME/env" ]] && source "$CARGO_HOME/env"

# ---------------------------------------------------------------------------
# Java — SDKMAN! (must be near the end; it appends to PATH itself)
# ---------------------------------------------------------------------------
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]] && source "$SDKMAN_DIR/bin/sdkman-init.sh"

# ---------------------------------------------------------------------------
# Ruby — rbenv or rvm, whichever the machine has
# ---------------------------------------------------------------------------
if command -v rbenv >/dev/null 2>&1; then
  eval "$(rbenv init - zsh)"
elif [[ -s "$HOME/.rvm/scripts/rvm" ]]; then
  path_prepend "$HOME/.rvm/bin"
  source "$HOME/.rvm/scripts/rvm"
fi

# ---------------------------------------------------------------------------
# Google Cloud SDK — the Homebrew cask, the standalone installer, or the
# Linux tarball, in that order.
# ---------------------------------------------------------------------------
for gcloud_root in \
  "$HOMEBREW_PREFIX/share/google-cloud-sdk" \
  "$HOME/google-cloud-sdk" \
  "/usr/lib/google-cloud-sdk"
do
  if [[ -f "$gcloud_root/path.zsh.inc" ]]; then
    source "$gcloud_root/path.zsh.inc"
    [[ -f "$gcloud_root/completion.zsh.inc" ]] && source "$gcloud_root/completion.zsh.inc"
    break
  fi
done
unset gcloud_root

# ---------------------------------------------------------------------------
# fzf
# ---------------------------------------------------------------------------
[[ -f "$HOME/.fzf.zsh" ]] && source "$HOME/.fzf.zsh"
export FZF_DEFAULT_OPTS="--height 40% --layout=reverse --border"
if command -v rg >/dev/null 2>&1; then
  export FZF_DEFAULT_COMMAND="rg --files --hidden --glob '!.git'"
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
fi

# ---------------------------------------------------------------------------
# direnv
# ---------------------------------------------------------------------------
command -v direnv >/dev/null 2>&1 && eval "$(direnv hook zsh)"

# ---------------------------------------------------------------------------
# iTerm2 shell integration (macOS)
# ---------------------------------------------------------------------------
[[ -e "$HOME/.iterm2_shell_integration.zsh" ]] && source "$HOME/.iterm2_shell_integration.zsh"

# ---------------------------------------------------------------------------
# Perl local::lib — only when the tree actually exists, since the eval fails
# noisily otherwise.
# ---------------------------------------------------------------------------
if [[ -d "$HOME/perl5/lib/perl5" ]]; then
  eval "$(perl -I"$HOME/perl5/lib/perl5" -Mlocal::lib="$HOME/perl5" 2>/dev/null)"
fi
