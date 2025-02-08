## Kubectl
command -v kubectl &>/dev/null && source <(kubectl completion zsh)

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
