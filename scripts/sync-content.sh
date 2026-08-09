#!/usr/bin/env bash
set -euo pipefail

export GIT_TERMINAL_PROMPT=0

CONTENT_REPO_HOST="forgejo.vaultlab.ru/Pavel/prohomelab-content.git"
CONTENT_DIR="/tmp/prohomelab-content"
TARGET_DIR="content/posts"

if [ -n "${CONTENT_REPO_TOKEN:-}" ]; then
  CONTENT_REPO_URL="https://Pavel:${CONTENT_REPO_TOKEN}@${CONTENT_REPO_HOST}"
else
  echo "ERROR: CONTENT_REPO_TOKEN is not set" >&2
  exit 1
fi

rm -rf "$CONTENT_DIR"
git clone --depth 1 "$CONTENT_REPO_URL" "$CONTENT_DIR"

rsync -a --delete \
  --exclude='.git' \
  --exclude='Prohomelab.base' \
  --exclude='_Prohomelab-Index.md' \
  "$CONTENT_DIR/" "$TARGET_DIR/"

find "$TARGET_DIR" -type f -name '*.md' -print0 | xargs -0 sed -i -E 's/!\[\[([^]]+)\]\]/![](\1)/g'

echo "Content synced and converted."
