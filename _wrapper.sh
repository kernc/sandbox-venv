#!/bin/sh
# sandbox-venv: container sandbox venv wrapper (GENERATED CODE)
set -eu
set -x
alias realpath='realpath --no-symlinks'
warn () { echo "sandbox-venv/wrapper: $*" >&2; }

VENV="$(realpath "${0%/*}/..")"
EXECUTABLE="${1:-/usr/bin/python}"
_BWRAP_DEFAULT_ARGS=

home='/home/user'

[ -e "$VENV/bin/python" ]  # Assertion

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
    /usr/share/ca-certificates
    /etc/pki
    /etc/ssl
    /usr/share/pki
    "
filter_existing_paths() { for p in $1; do [ ! -e "$p" ] || echo "$p"; done; }
ro_bind_extra="$(filter_existing_paths "$ro_bind_extra")"

collect="
    $collect
    $ro_bind_extra
    $py_libs"

# Filter collect, warn on non-existant paths, unique sort, cull.
# Use separate for-loop to expand globstar.
prev="sandbox@"
collect="$(
    for path in $collect; do
        [ -e "$path" ] ||
            # Don't warn for globstar paths as they are allowed to not match
            case "$path" in *\**) continue ;; *) warn "Warning: missing $path"; continue ;; esac
        echo "$path"
    done |
    sort -u |
    while IFS= read -r path; do
        case $path in "$prev"/*) continue;; esac
        echo "$path"; prev="$path"
    done)"

args=""; for path in $collect; do args="$args --ro-bind $path $path"; done

# RW-bind project dir (dir that contains .venv)
args="$args --bind $(realpath "$VENV/..") $home"

# but RO some dirs like .venv and git
ro_bind_pwd_extra="
    ${VENV##*/}
    .git"
for path in $ro_bind_pwd_extra; do
    [ ! -e "$VENV/../$path" ] || args="$args --ro-bind $(realpath "$VENV/../$path") $home/$path"
done

# RW bind cache dir for downloads etc.
pip_cache="${HOME:-"/home/$USER"}/.cache/pip"
mkdir -p "$VENV/cache"
mkdir -p "$pip_cache"
args="$args --bind $VENV/cache $home/.cache"
args="$args --bind $pip_cache $home/.cache/pip"

# Pass our own redacted copy of env
for var in $(env | grep -E '^(USER|SHLVL|SHELL|TERM|LANG|LC_.*)$'); do
    args="$args --setenv $(echo "$var" | tr '=' ' ')"
done

set $xtrace
chdir="$(realpath --relative-to "$VENV/.." "$(pwd)")"
chdir="$home/${chdir#"$(realpath "$VENV/..")"}"

format_args () { for arg in "$@"; do case "$arg" in *\ *) printf "'%s' " "$arg" ;; *) printf "%s " "$arg" ;; esac; done; }
warn "exec bwrap $(realpath "$VENV/bin/$EXECUTABLE") $(format_args "$@")"

# NOTE: Pass $args last
# shellcheck disable=SC2086
exec bwrap \
    --dir /tmp \
    --dir "/run/user/$(id -u)" \
    --proc /proc \
    --dev /dev \
    --chdir "$chdir" \
    --clearenv \
    --unshare-all \
    --share-net \
    --new-session \
    --die-with-parent \
    --setenv PS1 '\u @ \h \$' \
    --setenv HOME "$home" \
    --setenv USER "${home##*/}" \
    --setenv VIRTUAL_ENV "$home/${VENV##*/}" \
    $args \
    $_BWRAP_DEFAULT_ARGS \
    ${BWRAP_ARGS:-} \
    "$home/${VENV##*/}/bin/$EXECUTABLE" "$@"
