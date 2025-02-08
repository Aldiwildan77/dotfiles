ZSH_CUSTOM="$HOME/.oh-my-zsh/custom"

# Define plugin paths
AUTO_SUGGESTIONS="$ZSH_CUSTOM/plugins/zsh-autosuggestions"
SYNTAX_HIGHLIGHTING="$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"

[ ! -d "$AUTO_SUGGESTIONS" ] && git clone https://github.com/zsh-users/zsh-autosuggestions "$AUTO_SUGGESTIONS"
[ ! -d "$SYNTAX_HIGHLIGHTING" ] && git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$SYNTAX_HIGHLIGHTING"

# Load the Oh My Zsh plugins
plugins=(
  git                     # Provides Git aliases and functions
  golang                  # Golang development support
  kubectl                 # Autocompletion for kubectl commands
  gcloud                  # Google Cloud SDK integration
  copypath                # Copy path of current directory or file
  history                 # Enhances history functionality
  zsh-autosuggestions     # Suggest commands as you type
  zsh-syntax-highlighting # Colorizes commands for easier reading
  rails                   # Rails-related commands and aliases
  ruby                    # Ruby development shortcuts
  rake                    # Rake build system support
  fzf                     # Fuzzy finder integration
  z                       # Jump around directories
  httpie                  # HTTP client for the terminal
  npm                     # Node.js package manager
  yarn                    # Yarn package manager
  docker                  # Docker container management
  docker-compose          # Docker Compose management
  helm                    # Kubernetes Helm package manager
  minikube                # Local Kubernetes cluster management
  alias-finder            # Find and execute aliases
)
