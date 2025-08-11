#!/bin/sh
# sandbox-venv: Secure container sandbox venv wrapper (GENERATED CODE)
set -eu

alias realpath='realpath --no-symlinks'
warn () { echo "sandbox-venv/wrapper: $*" >&2; }

venv="$(realpath "${0%/*}/..")"

EXECUTABLE="${1:-/usr/bin/python}"
_BWRAP_DEFAULT_ARGS=

[ -e "$venv/bin/python" ]  # Assertion

# Expose these binaries
executables="
    /usr/bin/python
    /bin/env
    /bin/ls
    /bin/bash
    /bin/sh"

case $- in *x*) xtrace=-x ;; *) xtrace=+x ;; esac; set +x

# Collect binaries' lib dependencies
lib_deps () {
    readelf -l "$1" | awk '/interpreter/ {print $NF}' | tr -d '[]'
    ldd "$1" | awk '/=>/ { print $3 }' | grep -E '^/'
}
collect="$executables"
for exe in $executables; do
    collect="$collect
        $(lib_deps "$exe")"
done

# Explicit Python dependencies from Firejail
# TODO: Get lib deps from venv/lib/*.so
py_libs="
    /usr/include/python3*
    /usr/lib/python3*
    /usr/lib64/python3*
    /usr/local/lib/python3*
    /usr/share/python3*
    /usr/lib/*/libreadline.so*
    /usr/lib/**/libreadline.so*
    /usr/lib/**/libssl.so*
    /usr/lib/**/libcrypto.so*
    "
ro_bind_extra="
    /etc/resolv.conf
    /usr/share/ca-certificates*
    /etc/pki
    /etc/ssl
    /usr/share/pki*
    "

collect="
    $collect
    $ro_bind_extra
    $py_libs"

# Filter collect, warn on non-existant paths, unique sort, cull.
# Use separate for-loop to expand globstar.
prev="sandbox@"
collect="$(
    # Split only on newline
    for path in $collect; do
        path="$(printf '%s' "$path" | sed -r 's/^ +//;s/ +$//')"
        [ -e "$path" ] ||
            # Don't warn for globstar paths as they are allowed to not match
            case "$path" in *\**) continue ;; *) warn "Warning: missing $path"; continue ;; esac
        echo "$path"
    done |
    sort -u |
    # If collected paths contain /foo/ and /foo/bar,
    # keep only /foo since it covers both
    while IFS= read -r path; do
        case $path in "$prev"/*) continue;; esac
        echo "$path"; prev="$path"
    done)"

# Begins constructing args for bwrap, in reverse
# (later args in command line override prior ones)
IFS='
'  # Split args only on newline
set -- $_BWRAP_DEFAULT_ARGS ${BWRAP_ARGS:-} "${0%/*}/$EXECUTABLE" "$@"

for path in $collect; do set -- --ro-bind "$path" "$path" "$@"; done

# RW-bind project dir (dir that contains .venv)
# but RO-bind some dirs like .venv and git
proj_dir="$(realpath "$venv/..")"
ro_bind_pwd_extra="
    ${venv##*/}
    .git"
for path in $ro_bind_pwd_extra; do
    [ ! -e "$proj_dir/$path" ] || set -- --ro-bind "$proj_dir/$path" "$proj_dir/$path" "$@"
done
set -- --bind "$proj_dir" "$proj_dir" "$@"

# RW bind cache dir for downloads etc.
home="${HOME:-"/home/$USER"}"
pip_cache="$home/.cache/pip"
mkdir -p "$venv/cache" "$pip_cache"
# Use .venv/cache for general cache, $HOME/.cache/pip for pip cache
set -- --bind "$venv/cache" "$home/.cache" \
       --bind "$pip_cache" "$home/.cache/pip" "$@"

# Pass our own redacted copy of env
for var in $(env | grep -E '^(USER|LOGNAME|UID|SHLVL|SHELL|TERM|LANG|LC_.*|HOSTNAME)$'); do
    set -- --setenv "${var%%=*}" "${var#*=}" "$@"
done

set $xtrace

# Quote args with spaces
format_args () ( set +x; for arg in "$@"; do case "$arg" in *\ *) printf "'%s' " "$arg" ;; *) printf "%s " "$arg" ;; esac; done; )
warn "exec bwrap [...] $(format_args "$@")"

# shellcheck disable=SC2086
exec bwrap \
    --dir /tmp \
    --dir "/run/user/$(id -u)" \
    --dir "$(pwd)" \
    --chdir "$(pwd)" \
    --proc /proc \
    --dev /dev \
    --clearenv \
    --unshare-all \
    --share-net \
    --new-session \
    --die-with-parent \
    --setenv PS1 '\u @ \h \$' \
    --setenv HOME "$home" \
    --setenv USER "user" \
    --setenv VIRTUAL_ENV "$venv" \
    "$@"
