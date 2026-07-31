# Completion setup and zstyle configuration.

## Alias Finder
zstyle ':omz:plugins:alias-finder' autoload yes
zstyle ':omz:plugins:alias-finder' longer yes
zstyle ':omz:plugins:alias-finder' exact yes
zstyle ':omz:plugins:alias-finder' cheaper yes

## Docker
zstyle ':completion:*:*:docker:*' option-stacking yes
zstyle ':completion:*:*:docker-*:*' option-stacking yes

## Yarn
zstyle ':omz:plugins:yarn' berry yes

## General
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'   # case-insensitive
zstyle ':completion:*' menu select
zstyle ':completion:*' list-colors ''

# ---------------------------------------------------------------------------
# Tool completions
#
# `kubectl completion zsh` shells out and costs ~150ms of startup. Cache it and
# refresh once a day instead of paying that on every prompt. Same pattern for
# the others.
# ---------------------------------------------------------------------------
ZSH_COMPLETION_CACHE="$HOME/.cache/zsh/completions"
mkdir -p "$ZSH_COMPLETION_CACHE"
fpath=("$ZSH_COMPLETION_CACHE" $fpath)

_cache_completion() {
  local name="$1"; shift
  local cache="$ZSH_COMPLETION_CACHE/_$name"
  command -v "$name" >/dev/null 2>&1 || return 0
  # -N +1 is "newer than 1 day"; regenerate when the cache is missing or stale.
  if [[ ! -f "$cache" || -n "$(find "$cache" -mtime +1 2>/dev/null)" ]]; then
    "$@" > "$cache" 2>/dev/null || rm -f "$cache"
  fi
}

_cache_completion kubectl kubectl completion zsh
_cache_completion helm     helm completion zsh
_cache_completion gh       gh completion -s zsh
_cache_completion k9s      k9s completion zsh
_cache_completion stern    stern --completion=zsh
_cache_completion flyctl   flyctl completions zsh
_cache_completion temporal temporal completion zsh

# oh-my-zsh runs compinit itself; these only need to be on $fpath by then.
