#!/usr/bin/env zsh
# ------------------------------------------
# Zsh Configuration Loader
# Author: Muhammad Wildan Aldiansyah
# ------------------------------------------

## Which company profile to load, if any. Set COMPANY in the environment, or
## pass it as the first argument. Profiles live OUTSIDE this repo — see below.
COMPANY=${COMPANY:-$1}

## Where company profiles are kept. Untracked by design.
ZSHRC_D_LOCAL="${ZSHRC_D_LOCAL:-$HOME/.zshrc.d}"

## Load the dotfiles configuration
export DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
export ZSH="${ZSH:-$HOME/.oh-my-zsh}"

# ZSH Options
setopt AUTO_CD
setopt CORRECT
setopt HIST_IGNORE_DUPS
setopt SHARE_HISTORY

# Helper function to source a file if it exists
source_if_exists() {
  local file="$1"
  if [[ -r "$file" ]]; then
    source "$file"
  else
    # echo "Warning: $file not found or not readable."
    return 1
  fi
}

# --- before oh-my-zsh ------------------------------------------------------
# base.zsh sets $DOTFILES_OS and puts brew on PATH, so it comes first.
# plugins.zsh defines the $plugins array that oh-my-zsh.sh reads, and
# completions.zsh has to land on $fpath before oh-my-zsh runs compinit.
pre_omz=( base.zsh exports.zsh plugins.zsh completions.zsh )
for config in "${pre_omz[@]}"; do
  source_if_exists "$DOTFILES_DIR/zsh/zshrc.d/$config"
done

source "$ZSH/oh-my-zsh.sh"

# --- after oh-my-zsh -------------------------------------------------------
# Everything below has to win over the plugins. The yarn plugin, for example,
# aliases `y` to yarn, which would otherwise shadow the yazi function.
# tools.zsh is last so its version-manager PATH edits take precedence.
post_omz=( functions.zsh aliases.zsh tools.zsh )
for config in "${post_omz[@]}"; do
  source_if_exists "$DOTFILES_DIR/zsh/zshrc.d/$config"
done

# Company profile — depends on add_to_env from functions.zsh, so it goes here.
#
# Two locations, private first:
#
#   ~/.zshrc.d/<company>.zsh          never tracked — anything employer-private
#   zsh/profiles/<company>.zsh        tracked — only if it holds no secrets
#
# The private copy wins when both exist, so a tracked profile can carry the
# harmless parts while the untracked one adds cluster names and credentials.
# Profiles used to live in zsh/zshrc.d/<company>/ and put a GCP project id, an
# internal module domain and production cluster names into a public history —
# hence the split.
if [[ -n "$COMPANY" ]]; then
  source_if_exists "$ZSHRC_D_LOCAL/$COMPANY.zsh" \
    || source_if_exists "$DOTFILES_DIR/zsh/profiles/$COMPANY.zsh" \
    || echo "dotfiles: no profile for '$COMPANY' in $ZSHRC_D_LOCAL or $DOTFILES_DIR/zsh/profiles"
fi

# Machine-local overrides: secrets, work paths, anything that must not be
# committed. See zsh/.zshrc.local.example for the expected shape.
source_if_exists "$HOME/.zshrc.local"

unset pre_omz post_omz config ZSHRC_D_LOCAL
