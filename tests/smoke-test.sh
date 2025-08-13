#!/bin/sh
set -eu

. "${0%/*}/_init.sh"

sandbox-venv .venv

python -c 'import os; print(os.getcwd())'
assert_is_sandboxed python -c 'import os'
pip freeze --all
assert_is_sandboxed pip freeze
pip freeze --all 2>&1 | grep -q '=='
pip install --verbose -U pip
pip freeze --all

shell -c 'echo SHELL TEST OK'

printf '\n\n\n    ALL OK  ✅\n\n\n'
