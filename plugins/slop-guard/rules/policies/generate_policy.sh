#!/usr/bin/env bash
# Convert bash.yaml into bash arrays.
# Output format: DENY_PATTERNS=( "pat1" "pat2" ) ASK_PATTERNS=( "pat1" )

printf 'DENY_PATTERNS=('
# Extract only 'pattern:' fields in deny: block, excluding src_pattern/sink_pattern
sed -n '/deny:/,/ask:/p' "$1" | grep -E '^[[:space:]]*pattern:' | sed "s/.*pattern: '//;s/'//" | while read -r p; do printf '"%s" ' "$p"; done
printf ')\n'

printf 'ASK_PATTERNS=('
# Extract only 'pattern:' fields in ask: block
sed -n '/ask:/,$p' "$1" | grep -E '^[[:space:]]*pattern:' | sed "s/.*pattern: '//;s/'//" | while read -r p; do printf '"%s" ' "$p"; done
printf ')\n'
