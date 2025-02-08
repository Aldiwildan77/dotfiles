# Ruangguru-specific configuration

# Google Cloud SDK paths (if installed in Ruangguru's directory)
if [ -f "$HOME/google-cloud-sdk/path.zsh.inc" ]; then
  source "$HOME/google-cloud-sdk/path.zsh.inc"
fi
if [ -f "$HOME/google-cloud-sdk/completion.zsh.inc" ]; then
  source "$HOME/google-cloud-sdk/completion.zsh.inc"
fi

# For GONOPROXY
add_to_env GONOPROXY "gopkg.sirogu.com"
add_to_env GONOPROXY "gitlab.com/ruangguru"

# For GONOSUMDB
add_to_env GONOSUMDB "gopkg.sirogu.com"
add_to_env GONOSUMDB "gitlab.com/ruangguru"

# For GOPRIVATE
add_to_env GOPRIVATE "gopkg.sirogu.com"
add_to_env GOPRIVATE "gitlab.com/ruangguru"

# For Google Cloud credentials
export ROGU_KEY_PATH="$HOME/.config/gcloud/application_default_credentials.json"

# ALIASES

## Ruangguru workspace
alias rgw="cd $HOME/Workspace/Development/"

## Kubernetes aliases for Ruangguru contexts
alias kcrg='kubectl --context gke_silicon-airlock-153323_asia-southeast1-a_ruangguru-k8s'
alias skcrg='stern --context gke_silicon-airlock-153323_asia-southeast1-a_ruangguru-k8s'

## Stern Kubectl
alias skcrg='stern --context gke_silicon-airlock-153323_asia-southeast1-a_ruangguru-k8s'
alias skcid='stern --context gke_silicon-airlock-153323_asia-southeast1_ase1-id-prod-1'
