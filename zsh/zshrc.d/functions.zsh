# Shell functions.
#
# Sourced after oh-my-zsh. zsh refuses to define a function whose name is
# already an alias — and it fails the whole file at parse time, not just that
# line — so drop the colliding plugin aliases first. The yarn plugin's `y` is
# the one that bites; the rest are listed defensively.
unalias y mkcd dsh kexec 2>/dev/null

# add_to_env VARNAME VALUE — append to a comma-separated env var, once.
# Used for things like GOPRIVATE where the value is a comma-separated list.
add_to_env() {
  local varname="$1"
  local new_value="$2"
  local current_value="${(P)varname}"

  # Check if the new_value is already present by surrounding the list with commas.
  if [[ ",${current_value}," != *",$new_value,"* ]]; then
    if [[ -z "$current_value" ]]; then
      export $varname="$new_value"
    else
      export $varname="${current_value},${new_value}"
    fi
  fi
}

# y — open yazi and cd to wherever it was left when it exits.
y() {
  command -v yazi >/dev/null 2>&1 || { echo "yazi is not installed"; return 1; }
  local tmp cwd
  tmp="$(mktemp -t yazi-cwd.XXXXXX)"
  command yazi "$@" --cwd-file="$tmp"
  IFS= read -r -d '' cwd < "$tmp"
  [ -n "$cwd" ] && [ "$cwd" != "$PWD" ] && [ -d "$cwd" ] && builtin cd -- "$cwd"
  command rm -f -- "$tmp"
}

# mkcd DIR — make a directory and step into it.
mkcd() { mkdir -p "$1" && cd "$1"; }

# extract-port PORT — show what is listening on a port, on either platform.
whoisonport() {
  [[ -n "$1" ]] || { echo "usage: whoisonport <port>"; return 1; }
  if command -v lsof >/dev/null 2>&1; then
    lsof -nP -iTCP:"$1" -sTCP:LISTEN
  else
    ss -tlnp "sport = :$1"
  fi
}

# killport PORT — free a port that a crashed dev server is still holding.
killport() {
  [[ -n "$1" ]] || { echo "usage: killport <port>"; return 1; }
  local pids
  pids="$(lsof -ti tcp:"$1" 2>/dev/null)"
  if [[ -z "$pids" ]]; then
    echo "nothing is listening on port $1"
    return 0
  fi
  echo "killing: $pids"
  echo "$pids" | xargs kill -9
}

# gclone OWNER/REPO — clone into a consistent location and cd there.
gclone() {
  [[ -n "$1" ]] || { echo "usage: gclone <owner/repo>"; return 1; }
  local dest="${GIT_CLONE_ROOT:-$HOME/Workspace}/${1##*/}"
  git clone "https://github.com/$1" "$dest" && cd "$dest"
}

# dsh CONTAINER — shell into a running container, falling back to sh.
dsh() {
  [[ -n "$1" ]] || { echo "usage: dsh <container>"; return 1; }
  docker exec -it "$1" bash 2>/dev/null || docker exec -it "$1" sh
}

# kexec POD [CONTAINER] — same idea for Kubernetes.
kexec() {
  [[ -n "$1" ]] || { echo "usage: kexec <pod> [container]"; return 1; }
  if [[ -n "$2" ]]; then
    kubectl exec -it "$1" -c "$2" -- sh -c 'command -v bash >/dev/null && exec bash || exec sh'
  else
    kubectl exec -it "$1" -- sh -c 'command -v bash >/dev/null && exec bash || exec sh'
  fi
}

# dotfiles-update — pull the repo and re-link, without touching packages.
dotfiles-update() {
  git -C "$DOTFILES_DIR" pull --ff-only && \
    bash "$DOTFILES_DIR/install/bootstrap.sh" stow && \
    exec zsh
}
