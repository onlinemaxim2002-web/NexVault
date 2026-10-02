#!/usr/bin/env bash
# Runs the migrations + behaviour tests against a throwaway local Postgres.
# Usage: supabase/tests/run_tests.sh   (needs initdb/pg_ctl/psql on PATH or in
# /usr/lib/postgresql/*/bin)
set -euo pipefail

# Postgres refuses to run as root.
if [ "$(id -u)" = 0 ] && id postgres >/dev/null 2>&1; then
  exec runuser -u postgres -- bash "$0" "$@"
fi

here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/.." && pwd)"

if ! command -v pg_ctl >/dev/null; then
  PATH="$(ls -d /usr/lib/postgresql/*/bin | sort -V | tail -1):$PATH"
fi

data="$(mktemp -d)"
port=55432
cleanup() { pg_ctl -D "$data" -m immediate stop >/dev/null 2>&1 || true; rm -rf "$data"; }
trap cleanup EXIT

initdb -D "$data" -U postgres --auth=trust >/dev/null
pg_ctl -D "$data" -o "-p $port -k $data -c listen_addresses=''" -l "$data/log" -w start >/dev/null

run() { psql -h "$data" -p "$port" -U postgres -d postgres -v ON_ERROR_STOP=1 -q -t -A "$@" 2>&1 | sed -n "s/^psql:.*NOTICE:  //p; /ERROR/p; /^All tests/p; /^Applying/p"; }

run -f "$here/supabase_stub.sql"
for f in "$root"/migrations/*.sql; do
  echo "Applying $(basename "$f")"
  run -f "$f"
done
run -f "$here/rls_test.sql"
