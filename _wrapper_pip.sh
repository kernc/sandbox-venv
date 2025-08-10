#!/bin/sh
# sandbox-venv: Secure container sandbox venv wrapper (GENERATED CODE)
# pip wrapper: Re-run sandbox-venv after every pip installation
set -u
alias realpath='realpath --no-symlinks'

venv="$(realpath "${0%/*}/..")"

_BWRAP_DEFAULT_ARGS=

BWRAP_ARGS="${BWRAP_ARGS-} $_BWRAP_DEFAULT_ARGS --bind $venv $venv" \
    "$venv/bin/.unsafe_${0##*/}" "$@"
pip_return_status=$?

# [...] Auxiliary functions get inserted here

new_binaries="$(
    for file in "$venv/bin"/*; do
        [ -L "$file" ] || [ ! -x "$file" ] ||
            is_already_wrapped "$file" ||
            is_python_shebang "$file" ||
            printf ' %s' "${file##*/}"
    done)"

if [ "$new_binaries" ]; then
    # Reset shebang to the one outside the sandbox
    if [ "$(command -v sandbox-venv)" ]; then
        echo "sandbox-venv: New binaries found:$new_binaries. Re-running sandbox-venv ..."
        sandbox-venv "$venv"
    else echo "WARNING: sandbox-venv not in \$PATH. Cannot sandbox/patch new executables:$new_binaries. Rerun sandbox-venv on this venv to stay secure."
    fi
fi

exit $pip_return_status
