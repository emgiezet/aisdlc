#!/usr/bin/env bash
# lib/shellsplit.sh — robust shell command splitting.
# Splits compound commands into atomic components based on operators and groupings.

shellsplit() {
    python3 "$(dirname "${BASH_SOURCE[0]}")/shellsplit.py" "$1"
}
