#!/usr/bin/env python3
"""PermissionRequest hook: approve a Bash command whose every rm target is inside /tmp.

Claude Code asks before removing the working directory or one of its parents, even in
bypass mode, so cleaning up a /tmp scratch directory the shell has cd'd into stops the
agent. In bypass mode this hook answers that prompt; in other modes it stays out of the way.
"""
import json, os, shlex, sys

SEPARATORS = {";", "&&", "||", "|", "&", "\n", "(", ")", "|&"}
TMP_ROOTS = ("/tmp/", "/private/tmp/")


def in_tmp(target, cwd):
    if any(c in target for c in "$`~\n") or target.startswith("-"):
        return False
    path = os.path.normpath(os.path.join(cwd, target))
    for root in TMP_ROOTS:
        if path.startswith(root):
            first = path[len(root):].split("/")[0]
            return first != "" and first[0] not in "*?["
    return False


def all_rm_targets_in_tmp(command, cwd):
    lexer = shlex.shlex(command, posix=True, punctuation_chars=True)
    lexer.whitespace = " \t"  # keep newlines as separators
    lexer.whitespace_split = True
    try:
        tokens = list(lexer)
    except ValueError:
        return False
    found, at_start, i = False, True, 0
    while i < len(tokens):
        tok = tokens[i]
        if tok in SEPARATORS:
            at_start = True
        elif os.path.basename(tok) in ("rm", "rmdir"):
            if not at_start:
                return False  # rm fed by xargs, sudo, find -exec ...: targets unknown
            found, flags_done, i = True, False, i + 1
            while i < len(tokens) and tokens[i] not in SEPARATORS:
                arg = tokens[i]
                if arg.isdigit() and i + 1 < len(tokens) and tokens[i + 1][0] in "<>":
                    i += 1  # the 2 of 2>/dev/null
                    continue
                if arg[0] in "<>":
                    i += 2  # a redirection and its file
                    continue
                if arg == "--":
                    flags_done = True
                elif flags_done or not arg.startswith("-"):
                    if not in_tmp(arg, cwd):
                        return False
                i += 1
            continue
        else:
            at_start = False
        i += 1
    return found


event = json.load(sys.stdin)
if (
    event.get("permission_mode") == "bypassPermissions"
    and event.get("tool_name") == "Bash"
    and all_rm_targets_in_tmp(event["tool_input"]["command"], event.get("cwd", "/"))
):
    print(json.dumps({"hookSpecificOutput": {"hookEventName": "PermissionRequest", "decision": {"behavior": "allow"}}}))
