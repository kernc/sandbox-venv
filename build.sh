#!/bin/sh
set -eu

cd "${0%/*}"
script_file="sandbox-venv.sh"
data="$(cat "$script_file")"
out="build/${script_file%.sh}"
{
    printf '%s' "$data" | awk '{ print } /^# CUT HERE/ { exit }'
    cat "_wrapper.sh"
} > "$out"
chmod +x "$out"
echo "$out"
