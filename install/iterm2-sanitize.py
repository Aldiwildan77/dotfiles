#!/usr/bin/env python3
"""Sanitize an iTerm2 preferences plist so it is safe to commit.

iTerm2 keeps everything in one plist, including things that must never reach a
public repo:

  * Window arrangements embed each session's recorded shell command history.
    A command typed as `WHOP_SECRET=... some-cmd` is stored verbatim, so the
    arrangement carries a live credential. Arrangements are dropped wholesale.
  * Sessions also record every directory visited, which maps out private
    project and client names.
  * NoSync* keys are per-machine UI state (window positions, tip counters,
    installation id) that only cause churn in git.

What survives is settings: profiles, colours, fonts, key bindings and global
preferences. Window layouts are deliberately not synced — see
TOPLEVEL_DROP_EXACT.

Usage:
    iterm2-sanitize.py <source.plist> <dest.plist>

Exits non-zero without writing if a credential pattern survives, so a bad
export fails closed rather than landing in a commit.
"""

import os
import plistlib
import re
import sys

# Per-session keys that hold history or environment rather than layout.
SESSION_DROP = {
    "Commands",            # recorded shell command history — the credential risk
    "Directories",         # every directory the session visited
    "Environment",         # inherited env, includes PWD and anything exported
    "Hosts",               # shell-integration host log: user@host per cwd change
    "Hostname to Shell",   # same, keyed user@host
    "Substitutions",
    "Working Directory",
    "Tmux Window Name",
    "Session Contents",    # scrollback, when "save contents" is enabled
}

# Top-level keys that are per-machine state, or not worth the risk.
TOPLEVEL_DROP_EXACT = {
    # Arrangements are a snapshot of live sessions, not settings. Every session
    # in one carries its recorded command history and directory history, which
    # is how a secret passed inline as VAR=value ends up in the file. The
    # per-session scrubbing below would handle it, but a layout is not worth
    # relying on that: dropping the key removes the whole class of leak.
    # Re-export with this line removed if you decide you want layouts synced.
    "Window Arrangements",
    "NoSyncInstallationId",
    "PreventEscapeSequenceFromClearingHistory",
}
TOPLEVEL_DROP_PREFIX = ("NoSync",)

SECRET = re.compile(
    r"(?i)"
    r"(?:pass(?:word|wd)|secret|token|api[_-]?key|credential)\s*[=:]\s*\S+"
    r"|ghp_[A-Za-z0-9]{16,}"
    r"|gho_[A-Za-z0-9]{16,}"
    r"|sk-[A-Za-z0-9-]{16,}"
    r"|ws_[A-Za-z0-9]{24,}"
    r"|AKIA[0-9A-Z]{16}"
    r"|-----BEGIN [A-Z ]*PRIVATE KEY-----"
)

HOME = os.path.expanduser("~")
USER = os.path.basename(HOME)


def scrub(obj):
    """Recursively drop history keys and generalise the home directory."""
    if isinstance(obj, dict):
        out = {}
        for key, value in obj.items():
            if key in SESSION_DROP:
                continue
            if isinstance(value, dict) and "Session" in value:
                # A split/tab node: keep geometry, scrub the session under it.
                out[key] = scrub(value)
            else:
                out[key] = scrub(value)
        return out
    if isinstance(obj, list):
        return [scrub(v) for v in obj]
    if isinstance(obj, str):
        # Portable across machines and usernames; iTerm2 expands ~ itself.
        return obj.replace(HOME, "~") if HOME in obj else obj
    return obj


def find_secrets(obj, path=""):
    """Yield (path, snippet) for anything that should not be published.

    Credentials are the hard failure. The local username is included too: it is
    not itself a secret, but wherever it survives, some per-machine history key
    survived with it — which is exactly how the command log would come back.
    """
    if isinstance(obj, dict):
        for key, value in obj.items():
            if USER and USER in str(key):
                yield f"{path}/{key}", f"<username in key: {key[:50]}>"
            yield from find_secrets(value, f"{path}/{key}")
    elif isinstance(obj, list):
        for i, value in enumerate(obj):
            yield from find_secrets(value, f"{path}[{i}]")
    elif isinstance(obj, str):
        if SECRET.search(obj):
            yield path, obj[:80]
        elif USER and USER in obj:
            yield path, f"<username: {obj[:60]}>"


def main():
    if len(sys.argv) != 3:
        print(__doc__, file=sys.stderr)
        return 2
    src, dest = sys.argv[1], sys.argv[2]

    with open(src, "rb") as fh:
        data = plistlib.load(fh)

    before = len(data)
    data = {
        k: v
        for k, v in data.items()
        if k not in TOPLEVEL_DROP_EXACT and not k.startswith(TOPLEVEL_DROP_PREFIX)
    }
    dropped_top = before - len(data)

    data = scrub(data)

    leaks = list(find_secrets(data))
    if leaks:
        print("REFUSING TO WRITE — credential pattern survived sanitising:", file=sys.stderr)
        for path, snippet in leaks[:10]:
            print(f"  {path}\n     {snippet}", file=sys.stderr)
        print(
            "\nAdd the offending key to SESSION_DROP in this script, then re-run.",
            file=sys.stderr,
        )
        return 1

    # XML rather than binary so the file diffs usefully in review.
    with open(dest, "wb") as fh:
        plistlib.dump(data, fh, fmt=plistlib.FMT_XML, sort_keys=True)

    profiles = [b.get("Name") for b in data.get("New Bookmarks", [])]
    print(f"wrote {dest}")
    print(f"  dropped {dropped_top} per-machine / layout top-level keys")
    print(f"  profiles: {', '.join(p for p in profiles if p) or 'none'}")
    print(f"  settings: {len(data)} top-level keys (window layouts not synced)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
