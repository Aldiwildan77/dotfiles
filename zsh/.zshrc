#!/usr/bin/env zsh
# ------------------------------------------
# Zsh Configuration Loader
# Author: Muhammad Wildan Aldiansyah
# ------------------------------------------

## Load the company-specific configuration
COMPANY=${COMPANY:-$1}

## Load the dotfiles configuration
export DOTFILES_DIR="$HOME/dotfiles"
export ZSH="$HOME/.oh-my-zsh"

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

config_files=( base.zsh exports.zsh plugins.zsh aliases.zsh functions.zsh completions.zsh )
for config in "${config_files[@]}"; do
  source_if_exists "$DOTFILES_DIR/zsh/zshrc.d/$config"
done

if [[ -n "$COMPANY" ]]; then
  source_if_exists "$DOTFILES_DIR/zsh/zshrc.d/$COMPANY/$COMPANY.zsh"
fi

source "$ZSH/oh-my-zsh.sh"
