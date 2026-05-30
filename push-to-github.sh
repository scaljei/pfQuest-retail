#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# push-to-github.sh
# Run this once to create the GitHub repo and push both branches.
# Requires: git, gh (GitHub CLI) — install with: brew install gh  or  apt install gh
# ─────────────────────────────────────────────────────────────────────────────
set -e

REPO_NAME="pfQuest-retail"
DESCRIPTION="pfQuest by Shagu — ported to WoW retail 11.1.5"

echo "→ Authenticating with GitHub..."
gh auth login            # opens browser / prompts for token

echo "→ Creating repo '$REPO_NAME' on GitHub..."
gh repo create "$REPO_NAME" \
  --public \
  --description "$DESCRIPTION" \
  --source=. \
  --remote=upstream \
  --push

echo "→ Pushing upstream master branch..."
git push upstream master

echo "→ Pushing retail-11.1.5 branch..."
git push upstream retail-11.1.5

echo ""
echo "✓ Done!  Visit: https://github.com/$(gh api user -q .login)/$REPO_NAME"
