# Aliases.
#
# Cluster- and workspace-specific aliases (kcid, kcjkt, rgw, ...) are personal
# to one employer and live in ~/.zshrc.local, not here.

# ---------------------------------------------------------------------------
# Editors
# ---------------------------------------------------------------------------
alias codi="code-insiders"
alias v="vim"

# ---------------------------------------------------------------------------
# Modern replacements, only when the tool is actually installed
# ---------------------------------------------------------------------------
# Debian ships bat as `batcat` to avoid a name clash with the `bacula` tools.
if command -v batcat >/dev/null 2>&1; then
  alias bat="batcat"
  alias cat="batcat --paging=never"
elif command -v bat >/dev/null 2>&1; then
  alias cat="bat --paging=never"
fi

# Deliberately no `grep=rg` alias: rg's flags and default recursion differ
# enough from grep's that aliasing it breaks muscle memory in confusing ways.

# ---------------------------------------------------------------------------
# Listing
# ---------------------------------------------------------------------------
alias ll="ls -lh"
alias la="ls -lah"
alias l="ls -CF"

# ---------------------------------------------------------------------------
# Git
# ---------------------------------------------------------------------------
alias gdc="git diff --shortstat --cached"                                       # Diff Cached
alias current_branch="git symbolic-ref --short HEAD 2>/dev/null || echo error"  # Current Branch
alias gwip="git add -A && git commit -m 'wip'"
alias gundo="git reset --soft HEAD~1"

# Regenerate Key Git — `ssh-add -K` is macOS-only; Linux uses the plain form.
if [[ "$DOTFILES_OS" == "macos" ]]; then
  alias rkgit='ssh-add --apple-use-keychain ~/.ssh/id_rsa'
else
  alias rkgit='ssh-add ~/.ssh/id_rsa'
fi

# ---------------------------------------------------------------------------
# Kubernetes
# ---------------------------------------------------------------------------
alias k="kubectl"
alias kccc='kubectl config current-context'
alias kgc='kubectl config get-contexts'
alias kgp='kubectl get pods'
alias kgn='kubectl get nodes'
alias kaf='kubectl apply -f'
alias kdes='kubectl describe'

# ---------------------------------------------------------------------------
# Docker
# ---------------------------------------------------------------------------
alias dps="docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"
alias dcu="docker compose up -d"
alias dcd="docker compose down"
alias dcl="docker compose logs -f"
alias dprune="docker system prune -af --volumes"

# ---------------------------------------------------------------------------
# Terraform
# ---------------------------------------------------------------------------
alias tf="terraform"
alias tfp="terraform plan"
alias tfa="terraform apply"

# ---------------------------------------------------------------------------
# Networking / sysadmin
# ---------------------------------------------------------------------------
alias myip="curl -s https://ipecho.net/plain; echo"
alias localip="ipconfig getifaddr en0 2>/dev/null || hostname -I 2>/dev/null | awk '{print \$1}'"
alias ports="lsof -nP -iTCP -sTCP:LISTEN 2>/dev/null || ss -tlnp"
alias h="history"
alias reload="exec zsh"

# ---------------------------------------------------------------------------
# Dotfiles
# ---------------------------------------------------------------------------
alias dotfiles="cd \$DOTFILES_DIR"
alias dotedit="\$EDITOR \$DOTFILES_DIR"
