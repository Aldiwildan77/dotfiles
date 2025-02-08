# code insiders
alias codi="code-insiders"

# Regenerate Key Git
alias rkgit='ssh-add -K ~/.ssh/id_rsa'

# Git
alias gdc="git diff --shortstat --cached $1" # Diff Cached
alias current_branch="git symbolic-ref --short HEAD 2>/dev/null || echo error" # Current Branch

# My IP
alias myip="curl http://ipecho.net/plain; echo"
