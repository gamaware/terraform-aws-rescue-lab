#!/usr/bin/env bash
# Starts moto_proxy on localhost, replays the prod state migration
# (migration/demo/run-local-demo.sh) against it, and stops the emulator on exit.
# No AWS account and no credentials are involved.
set -euo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
port="${MOTO_PORT:-5005}"
moto="${MOTO:-moto[server,proxy]==5.2.3}"
log="$(mktemp)"

# Resolve moto once so the first download does not count against the start-up wait.
uvx --from "$moto" python -c 'import moto' >/dev/null
MOTO_ACCOUNT_ID=111122223333 MOTO_IAM_LOAD_MANAGED_POLICIES=true uvx --from "$moto" moto_proxy -H 127.0.0.1 -p "$port" >"$log" 2>&1 &
moto_pid=$!
trap 'kill "$moto_pid" 2>/dev/null || true; rm -f "$log"' EXIT

tries=0
until [ "$tries" -ge 60 ]; do
  tries=$((tries + 1))
  if curl -fsS --proxy "http://127.0.0.1:$port" -X POST http://motoapi.amazonaws.com/moto-api/reset >/dev/null 2>&1; then
    break
  fi
  if ! kill -0 "$moto_pid" 2>/dev/null; then
    cat "$log" >&2
    echo "moto_proxy exited before it was ready" >&2
    exit 1
  fi
  sleep 1
done
if [ "$tries" -ge 60 ]; then
  echo "moto_proxy did not answer on 127.0.0.1:$port within 60 seconds" >&2
  exit 1
fi

MOTO_PROXY="http://127.0.0.1:$port" "$repo/migration/demo/run-local-demo.sh"
