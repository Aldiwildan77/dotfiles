# Login shells read this; interactive non-login shells read ~/.bashrc.
# Sourcing one from the other keeps both paths identical.
[ -f "$HOME/.bashrc" ] && . "$HOME/.bashrc"

# macOS: the VS Code CLI is not on PATH unless the app installed it.
if [ -d "/Applications/Visual Studio Code.app/Contents/Resources/app/bin" ]; then
  export PATH="$PATH:/Applications/Visual Studio Code.app/Contents/Resources/app/bin"
fi
