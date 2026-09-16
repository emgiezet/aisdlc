#!/usr/bin/env bash
# Convert bash.yaml into bash sourceable file with safe escaping.
# Output format: 
# DENY_PATTERNS=( 'pat1' 'pat2' )
# ASK_PATTERNS=( 'pat1' )

printf 'DENY_PATTERNS=('
sed -n '/deny:/,/ask:/p' "$1" | grep 'pattern:' | sed "s/.*pattern: '//;s/'//" | while read -r p; do
    printf '%q ' "$p"
done
printf ')\n'

printf 'ASK_PATTERNS=('
sed -n '/ask:/,$p' "$1" | grep 'pattern:' | sed "s/.*pattern: '//;s/'//" | while read -r p; do
    printf '%q ' "$p"
done
printf ')\n'
