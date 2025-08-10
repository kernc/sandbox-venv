#!/bin/sh
# sandbox-venv: container sandbox venv wrapper
# Wraps all .venv/bin entry‑points so they run under bubblewrap.
# Also re‑wrap any new scripts post installation by pip etc.
# shellcheck disable=SC2317
set -eu

for arg; do case "$arg" in -h|-\?|--help) echo "Usage: ${0##*/} [VENV_DIR] [BWRAP_OPTS]    # Dir defaults to .venv"; exit ;; esac; done

warn () { echo "sandbox-venv: $*" >&2; }
alias realpath='realpath --no-symlinks'

command -v bwrap >/dev/null || { warn 'Required command bwrap missing; apt install bubblewrap ?' ; exit 1; }

# Filter args s.t. $@ == bwrap extra args
venv='.venv'; [ $# -eq 0 ] || case "$1" in -*) ;; *) venv="$(realpath "$1")"; shift ;; esac

cd "$venv/bin" || { warn 'Error: Missing venv. Make a venv: python -m venv .venv'; exit 1; }
cd "../.."  # I.e. the project dir
venv="${venv##*/}"
bin="$venv/bin"
[ -d "$bin" ] || { warn 'Assertion failed'; exit 2; }
this_script="$0"
[ -f "$this_script" ] || this_script="$(command -v "$this_script")"
[ -f "$this_script" ] || { warn 'Assertion failed'; exit 3; }

is_python_shebang () {
    shebang_line="$(head -n1 "$1" | tr -d '\0')"
    test "${shebang_line#\#!}" = "$(realpath "$bin/python")"
}
is_already_wrapped () { head -n2 "$1" | grep -q '^# sandbox-venv'; }
export_func () { awk "/^$1 \(\) {/,/^}|; }\$/" "$0"; }

wrap_pip () {
    cat >"$1" <<EOF
#!/bin/sh
# sandbox-venv: container sandbox venv wrapper (GENERATED CODE)
# pip wrapper: Re-run sandbox-venv.sh after every pip invocation
set -u
alias realpath='realpath --no-symlinks'

venv="\$(realpath "\${0%/*}/..")"

BWRAP_ARGS="--bind \$venv \$venv" \
    "\$venv/bin/.unsafe_${1##*/}" "\$@"
pip_return_status=\$?

$(export_func is_python_shebang)
$(export_func is_already_wrapped)

new_binaries="\$(
    for file in "\$venv/bin"/*; do
        [ -L "\$file" ] || [ ! -x "\$file" ] ||
            is_already_wrapped "\$file" ||
            is_python_shebang "\$file" ||
            printf '%s\n' "\${file##*/}"
    done)"

if [ "\$new_binaries" ]; then
    # Reset shebang to the one outside the sandbox
    if [ "\$(command -v sandbox-venv)" ]; then
        echo "sandbox-venv: New binaries found:\$new_binaries. Re-running sandbox-venv ..."
        sandbox-venv "\$venv"
    else echo "WARNING: sandbox-venv not in \\\$PATH. Cannot sandbox/patch new executables:\$new_binaries. Rerun sandbox-venv on this venv to stay secure."
    fi
fi

exit \$pip_return_status
EOF
}

wrap_executable () {
    bin_file="$1" executable="$2"; shift 2
    awk '/^# CUT HERE/{p=1; next} p' "$this_script" |
        sed -E -e "s|^EXECUTABLE=.*|EXECUTABLE='${executable##*/}'|" \
               -e "s|^_BWRAP_DEFAULT_ARGS=.*|_BWRAP_DEFAULT_ARGS=\"$*\"|" \
        > "$bin_file"
    grep -q 'GENERATED CODE' "$bin_file"  # Assertion
}

wrap_all () (
    for file in "$bin"/*; do
        # shellcheck disable=SC2015
        [ -f "$file" ] && [ -x "$file" ] || continue
        ! is_already_wrapped "$file" || continue
        case "${file##*/}" in pip*) ;; *) ! is_python_shebang "$file" || continue ;; esac  # Skip if wrapped transitively, except pip
        # shellcheck disable=SC2015
        [ -L "$file" ] && case "$(readlink "$file")" in /*) ;; *) continue ;; esac || true  # Skip relative symlinks

        unsafe_file="$bin/.unsafe_${file##*/}"
        if ! is_already_wrapped "$file"; then
            mv -v "$file" "$unsafe_file"
        fi

        case "${file##*/}" in
            pip|pip3*) wrap_pip "$file" "$@" ;;
            *) wrap_executable "$file" "$unsafe_file" "$@" ;;
        esac
        chmod +x "$file"
        echo "$file"
    done
)

wrap_all "$@"
exit 0

# CUT HERE ------------------------ Appendix I: sandbox-venv wrapper.sh script
