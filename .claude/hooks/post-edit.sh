#!/usr/bin/env bash
# PostToolUse hook: format the file that was just edited.
set -euo pipefail

file="$(jq -r '.tool_input.file_path // empty')"
[ -f "$file" ] || exit 0

case "$file" in
  *.tf | *.tftest.hcl)
    terraform fmt "$file" >/dev/null 2>&1 || true
    ;;
  *.sh)
    if command -v shellharden >/dev/null 2>&1; then
      shellharden --replace "$file" 2>/dev/null || true
    fi
    if head -n 1 "$file" | grep -q '^#!'; then
      chmod +x "$file"
    fi
    ;;
  *.md)
    if command -v markdownlint >/dev/null 2>&1; then
      markdownlint --fix "$file" 2>/dev/null || true
    fi
    ;;
esac
