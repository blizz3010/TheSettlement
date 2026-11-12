#!/usr/bin/env bash
# Fresh isolated profile per configuration; never reads/writes production saves.
# Usage: bash raid/tests/run_relay_seed_matrix.sh [output-directory]
set -uo pipefail
project=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
output=${1:-"$project/../validation-procedural-20261110"}
mkdir -p "$output"
output=$(cd "$output" && pwd)
profile_root=$(mktemp -d /tmp/relay-seed-matrix.XXXXXX)
mkdir -p "$profile_root/version"/{data,config,cache}
XDG_DATA_HOME="$profile_root/version/data" XDG_CONFIG_HOME="$profile_root/version/config" XDG_CACHE_HOME="$profile_root/version/cache" godot --version > "$output/engine-version.txt" 2>&1
if ! grep -q '^4\.6\.3\.' "$output/engine-version.txt"; then
  printf 'Godot 4.6.3 required; see %s/engine-version.txt\n' "$output" >&2
  exit 2
fi
printf '%s\n' "$profile_root" > "$output/disposable-profile.txt"
printf 'case_index\texit_code\n' > "$output/exit-codes.tsv"
status=0
for index in 0 1 2 3 4 5; do
  profile="$profile_root/case-$index"
  mkdir -p "$profile"/{data,config,cache}
  XDG_DATA_HOME="$profile/data" XDG_CONFIG_HOME="$profile/config" XDG_CACHE_HOME="$profile/cache" godot --headless --fixed-fps 60 --path "$project" --script res://raid/tests/test_relay_seed_matrix.gd -- "--matrix-index=$index" > "$output/matrix-case-$index.log" 2>&1
  result=$?
  printf '%s\t%s\n' "$index" "$result" >> "$output/exit-codes.tsv"
  if [[ "$result" -ne 0 ]]; then status=1; fi
  printf 'Case %s exit %s: %s/matrix-case-%s.log\n' "$index" "$result" "$output" "$index"
done
printf 'Disposable profiles retained for audit at %s\n' "$profile_root"
exit "$status"
