#!/usr/bin/env bash
# Convert bash.yaml into bash arrays.
# Output format: DENY_PATTERNS=( "pat1" "pat2" ) ASK_PATTERNS=( "pat1" )

printf 'DENY_PATTERNS=('
# Extract all pattern fields in deny: block
sed -n '/deny:/,/ask:/p' "$1" | grep -E '(pattern|src_pattern|sink_pattern):' | sed "s/.*: '//;s/'//" | while read -r p; do printf '"%s" ' "$p"; done
printf ')\n'

printf 'ASK_PATTERNS=('
# Extract all pattern fields in ask: block
sed -n '/ask:/,$p' "$1" | grep -E '(pattern|src_pattern|sink_pattern):' | sed "s/.*: '//;s/'//" | while read -r p; do printf '"%s" ' "$p"; done
printf ')\n'
