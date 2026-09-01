#!/usr/bin/env bash
set -euo pipefail

OWNER="${1:-makarovrush-ctrl}"
REPO="xuanxue-research"
REMOTE="https://github.com/${OWNER}/${REPO}.git"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Run this script from the xuanxue-research repo root." >&2
  exit 1
fi

if ! gh repo view "${OWNER}/${REPO}" >/dev/null 2>&1; then
  echo "Creating GitHub repo ${OWNER}/${REPO} ..."
  gh repo create "${OWNER}/${REPO}" \
    --public \
    --description "玄学研究 Cursor Agent · 紫微斗数 (ziwei-doushu skill)" \
    --source . \
    --remote origin \
    --push
  exit 0
fi

if git remote get-url origin >/dev/null 2>&1; then
  git remote set-url origin "$REMOTE"
else
  git remote add origin "$REMOTE"
fi

git push -u origin main
