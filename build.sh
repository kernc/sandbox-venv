#!/bin/sh
set -eu

cd "${0%/*}"
script_file="sandbox-venv.sh"
out="build/${script_file%.sh}"
{
    cat "$script_file"
    appendix_cnt=1
    for appendix in _wrapper_pip _wrapper_exe; do
        printf '\n\n'
        echo "# CUT HERE ------------------- Appendix $appendix_cnt: sandbox-venv $appendix.sh script"
        cat "$appendix.sh"
        appendix_cnt=$((appendix_cnt + 1))
    done
} > "$out"
chmod +x "$out"
echo "$out"
