#!/usr/bin/env bash
# Convert bash.yaml into a bash sourceable file.

printf 'check_patterns() {\n'
# Extract only lines with pattern:
sed -n '/deny:/,/ask:/p' "$1" | sed '1d' | grep 'pattern:' | while read -r line; do
    pat=$(echo "$line" | sed "s/.*pattern: '\(.*\)'/\1/")
    printf '  [[ "$1" =~ %s ]] && return 1\n' "$pat"
done
printf '  return 0\n}\n'
