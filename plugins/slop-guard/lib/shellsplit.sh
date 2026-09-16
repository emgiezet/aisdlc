#!/usr/bin/env bash
# lib/shellsplit.sh — robust shell command splitting.
# Splits compound commands into atomic components based on operators.

shellsplit() {
    # Using python to split by operators: &&, ||, |, ;
    python3 -c "import sys, re; print('\n'.join(re.split(r'(&&|\|\||\||;)', sys.argv[1])))" "$1"
}
