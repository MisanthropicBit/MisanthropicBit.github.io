#!/usr/bin/env bash
# Source: https://jaspervdj.be/hakyll/tutorials/github-pages-tutorial.html

# Save uncommited changes
git stash

# Change to the development branch
git checkout develop

# Rebuild the site
stack exec site rebuild

# Fetch all remotes and create a branch tracking the remote master
git fetch --all
git checkout -b master --track origin/master

# Update the master branch with the contents of '_site', ignoring dotfiles and
# Hakyll output directories and deleting deleted files
rsync -a --filter='P _site/'      \
         --filter='P _cache/'     \
         --filter='P .git/'       \
         --filter='P .gitignore'  \
         --filter='P .stack-work' \
         --delete-excluded        \
         _site/ .

# Stage all files
git add -A

# Ask user for commit message and commit
read -p 'Enter commit message: ' commit_msg
git commit -m "$commit_msg"

# Push updates to master
git push origin master:master

# Revert back to the development branch, delete the master branch and update
# the working tree with the stashed changes
git checkout develop
git branch -D master
git stash pop
