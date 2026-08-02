# Oh My Zsh plugin list.
#
# This file must be sourced before oh-my-zsh.sh — that is what reads $plugins.
# Cloning the custom plugins is install/shell.sh's job; the check below is a
# safety net for a machine where .zshrc was linked without running the installer.

ZSH_CUSTOM="${ZSH_CUSTOM:-$ZSH/custom}"

for repo in \
  "zsh-autosuggestions https://github.com/zsh-users/zsh-autosuggestions" \
  "zsh-syntax-highlighting https://github.com/zsh-users/zsh-syntax-highlighting"
do
  plugin_name="${repo%% *}"
  plugin_url="${repo##* }"
  if [[ ! -d "$ZSH_CUSTOM/plugins/$plugin_name" ]]; then
    echo "dotfiles: cloning $plugin_name"
    git clone --depth=1 "$plugin_url" "$ZSH_CUSTOM/plugins/$plugin_name"
  fi
done
unset repo plugin_name plugin_url

plugins=(
  git                     # Git aliases and functions
  gitignore               # gi <lang> — fetch .gitignore templates
  golang                  # Golang development support
  rust                    # cargo completions
  python                  # Python helpers and venv shortcuts
  pip                     # pip completions
  ruby                    # Ruby development shortcuts
  rails                   # Rails-related commands and aliases
  rake                    # Rake build system support
  node                    # Node.js helpers
  npm                     # Node.js package manager
  yarn                    # Yarn package manager
  bun                     # Bun completions
  composer                # PHP dependency manager

  kubectl                 # Autocompletion for kubectl commands
  helm                    # Kubernetes Helm package manager
  minikube                # Local Kubernetes cluster management
  docker                  # Docker container management
  docker-compose          # Docker Compose management
  terraform               # Terraform completions
  ansible                 # Ansible aliases
  aws                     # AWS CLI profile switching
  gcloud                  # Google Cloud SDK integration

  fzf                     # Fuzzy finder integration
  z                       # Jump around directories
  copypath                # Copy path of current directory or file
  copyfile                # Copy file contents to the clipboard
  history                 # Enhances history functionality
  httpie                  # HTTP client for the terminal
  jsontools               # pp_json, is_json, urlencode_json
  extract                 # `extract <archive>` for any format
  sudo                    # ESC ESC prepends sudo to the current line
  command-not-found       # suggest the package providing a missing command
  alias-finder            # Find and execute aliases

  zsh-autosuggestions     # Suggest commands as you type
  zsh-syntax-highlighting # Colorizes commands for easier reading — keep last
)

# macOS-only plugins
if [[ "$DOTFILES_OS" == "macos" ]]; then
  plugins+=(macos brew xcode)
fi
