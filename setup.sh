#!/bin/bash
echo "Setting up dotfiles..."

# Install required packages
if [[ "$OSTYPE" == "darwin"* ]]; then
    brew install stow peco git
else
    sudo apt install -y stow peco git
fi

stow zsh vim git screen dig wget

echo "Dotfiles setup completed!"
