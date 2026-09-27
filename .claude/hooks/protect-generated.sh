#!/usr/bin/env bash
# PreToolUse hook: block hand edits to generated files. Exit 2 blocks the edit
# and sends the message on stderr back to the editor.
set -euo pipefail

file="$(jq -r '.tool_input.file_path // empty')"

case "$file" in
  */report/REPORT.pdf | */report/REPORT.sha256)
    echo "report/REPORT.pdf and REPORT.sha256 are generated: edit report/REPORT.md, then run make report." >&2
    exit 2
    ;;
  */report/evidence/*)
    echo "report/evidence/ is scanner output: run make evidence and review the diff." >&2
    exit 2
    ;;
  */docs/diagrams/*.svg | */docs/diagrams/*.png)
    echo "Diagram exports are generated: edit the .drawio source and export with the draw.io CLI." >&2
    exit 2
    ;;
  */.terraform.lock.hcl)
    echo "Lock files are written by terraform init and terraform providers lock, not by hand." >&2
    exit 2
    ;;
esac
