#!/bin/bash

# Set up Git user
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"

# Generate SSH key if it doesn't exist
if [ ! -f ~/.ssh/id_rsa ]; then
  ssh-keygen -t rsa -b 4096 -C "your.email@example.com" -N "" -f ~/.ssh/id_rsa
fi

# Start the SSH agent
eval "$(ssh-agent -s)"

# Add the SSH key to the agent
ssh-add ~/.ssh/id_rsa

# Print the public key to copy
echo "Copy this public key to your GitHub account:"
cat ~/.ssh/id_rsa.pub

# Clone the specified repository (replace with your repo URL)
REPO_URL="git@github.com:username/repo.git"
git clone $REPO_URL
