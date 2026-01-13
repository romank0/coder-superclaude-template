#!/bin/bash
# Setup script for GitHub integration in Claude Code workspace

set -e

echo "=== GitHub Setup for Claude Code Workspace ==="
echo

# Check if SSH key exists
if [ ! -f ~/.ssh/id_ed25519 ] && [ ! -f ~/.ssh/id_rsa ]; then
    echo "No SSH key found. Would you like to:"
    echo "1) Generate a new SSH key"
    echo "2) Paste an existing SSH key"
    echo "3) Skip SSH setup"
    read -p "Choice [1-3]: " choice

    case $choice in
        1)
            read -p "Enter your email for the SSH key: " email
            ssh-keygen -t ed25519 -C "$email" -f ~/.ssh/id_ed25519 -N ""
            echo
            echo "=== Your new public key (add this to GitHub) ==="
            cat ~/.ssh/id_ed25519.pub
            echo
            ;;
        2)
            echo "Paste your private key (end with Ctrl+D on a new line):"
            cat > ~/.ssh/id_ed25519
            chmod 600 ~/.ssh/id_ed25519
            echo "Key saved."
            ;;
        3)
            echo "Skipping SSH setup."
            ;;
    esac
fi

# Add GitHub to known hosts
if ! grep -q "github.com" ~/.ssh/known_hosts 2>/dev/null; then
    echo "Adding GitHub to known hosts..."
    ssh-keyscan github.com >> ~/.ssh/known_hosts 2>/dev/null
fi

# Test SSH connection
echo
echo "Testing SSH connection to GitHub..."
if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
    echo "SSH authentication successful!"
else
    echo "SSH authentication may need setup. You can also use gh CLI."
fi

# Configure git if not already
if [ -z "$(git config --global user.name)" ]; then
    read -p "Enter your Git name: " git_name
    git config --global user.name "$git_name"
fi

if [ -z "$(git config --global user.email)" ]; then
    read -p "Enter your Git email: " git_email
    git config --global user.email "$git_email"
fi

# Offer to authenticate with gh CLI
echo
read -p "Would you like to authenticate with GitHub CLI (gh)? [y/N]: " gh_auth
if [ "$gh_auth" = "y" ] || [ "$gh_auth" = "Y" ]; then
    gh auth login
fi

echo
echo "=== Setup Complete ==="
echo "You can now clone repositories:"
echo "  git clone git@github.com:owner/repo.git"
echo "  gh repo clone owner/repo"
