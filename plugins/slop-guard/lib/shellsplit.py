#!/usr/bin/env python3
"""Split shell text on executable control operators without invoking a shell."""

from __future__ import annotations

import sys


def split(command: str) -> list[str]:
    parts: list[str] = []
    current: list[str] = []
    quote: str | None = None
    escaped = False
    i = 0

    def flush() -> None:
        value = "".join(current).strip()
        if value:
            parts.append(value)
        current.clear()

    while i < len(command):
        char = command[i]
        if escaped:
            current.append(char)
            escaped = False
            i += 1
            continue
        if char == "\\" and quote != "'":
            current.append(char)
            escaped = True
            i += 1
            continue
        if char == "'":
            current.append(char)
            if quote is None:
                quote = "'"
            elif quote == "'":
                quote = None
            i += 1
            continue
        if char == '"':
            current.append(char)
            if quote is None:
                quote = '"'
            elif quote == '"':
                quote = None
            i += 1
            continue

        executable_context = quote != "'"
        if executable_context and char == "`":
            flush()
            end = i + 1
            escaped_tick = False
            body: list[str] = []
            while end < len(command):
                tick_char = command[end]
                if tick_char == "`" and not escaped_tick:
                    break
                body.append(tick_char)
                escaped_tick = tick_char == "\\" and not escaped_tick
                if tick_char != "\\":
                    escaped_tick = False
                end += 1
            parts.extend(split("".join(body)))
            i = min(end + 1, len(command))
            continue

        if executable_context and command.startswith("$(", i):
            flush()
            depth = 1
            end = i + 2
            inner_quote: str | None = None
            inner_escaped = False
            body: list[str] = []
            while end < len(command) and depth:
                inner_char = command[end]
                if inner_escaped:
                    body.append(inner_char)
                    inner_escaped = False
                elif inner_char == "\\" and inner_quote != "'":
                    body.append(inner_char)
                    inner_escaped = True
                elif inner_char in "'\"":
                    body.append(inner_char)
                    if inner_quote is None:
                        inner_quote = inner_char
                    elif inner_quote == inner_char:
                        inner_quote = None
                elif inner_quote is None and command.startswith("$(", end):
                    body.append("$(")
                    depth += 1
                    end += 1
                elif inner_quote is None and inner_char == ")":
                    depth -= 1
                    if depth:
                        body.append(inner_char)
                else:
                    body.append(inner_char)
                end += 1
            parts.extend(split("".join(body)))
            i = end
            continue

        if quote is None:
            operator = ""
            if command.startswith("&&", i) or command.startswith("||", i):
                operator = command[i : i + 2]
            elif char in ";|()":
                operator = char
            if operator:
                flush()
                parts.append(operator)
                i += len(operator)
                continue

        current.append(char)
        i += 1

    flush()
    return parts


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("usage: shellsplit.py COMMAND")
    for part in split(sys.argv[1]):
        print(part)
