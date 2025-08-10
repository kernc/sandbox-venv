#!/bin/sh
set -eu
set -x

packages="
black
coverage
fastapi
flask
flake8
httpx
numpy
pandas
pipenv
poetry
pydantic
pytest
requests
tox
uv
virtualenv
wheel
"

venv_dir=".sandbox-venv"
trap "rm -rf '$venv_dir'" INT HUP TERM EXIT

/usr/bin/python -m venv "$venv_dir"
sandbox-venv "$venv_dir" >&2
. "$venv_dir/bin/activate"

assert_is_sandboxed () { "$@" 2>&1 | grep -q 'sandbox-venv/wrapper: exec bwrap'; }

assert_is_sandboxed pip debug

printf "%-8s\t%s\t%s\n" "PACKAGE" "DEPS" "SIZE" | tee "${0%/*}/deps-stats.txt"

for pkg in $packages; do
    pip install "$pkg" >&2

    deps_dirs="$(
        find "$venv_dir/lib/python3.11/site-packages/" -type d -maxdepth 1 |
        grep -v '__pycache__' |
        grep -vP '/(pip|setuptools|pkg_resources)([/-]|$)' |
        grep -v 'site-packages/$')"
    count="$(echo "$deps_dirs" | wc -l)"
    size="$(
        echo "$deps_dirs" |
        xargs du -c --si --exclude __pycache__ --exclude licenses |
        tail -n1 | cut -f1)"
    printf "%-8s\t%s\t%s\n" "$pkg" "$((count - 1))" "$size" | tee -a "${0%/*}/deps-stats.txt"

    pip freeze | xargs --no-run-if-empty -- pip uninstall -y >&2
done
