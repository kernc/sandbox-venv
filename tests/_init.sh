#!/bin/sh
set -eu

PS4="$(
    if [ "${LINENO:-}" ] && [ "${BASH_VERSION:-}" ]; then lineno=':${LINENO-}>'; fi
    printf "\033[36;40;1m+%s${lineno:-}\033[0m " "$0"
)"
export PS4
set -x

"${0%/*}/../build.sh"

PATH="$(realpath "${0%/*}")/../build:$PATH"
LC_ALL=C

tmpdir="$(mktemp -d -t sandbox-venv_test-XXXXXXX)"
# shellcheck disable=SC2064
trap "tree -a -L 4 --si --du '$tmpdir'; rm -fr '$tmpdir'; trap - INT HUP EXIT TERM" INT HUP TERM EXIT
if [ ! "${CI-}" ]; then case "$tmpdir" in /tmp*|/var/*) ;; *) exit 9 ;; esac; fi

cd "$tmpdir"

/usr/bin/python3 -m venv .venv
. .venv/bin/activate
