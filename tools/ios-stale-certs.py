#!/usr/bin/env python3
"""Finds distribution certificates this build's own failed attempts left behind.

Apple allows two Apple Distribution certificates per account. Every build that
generates a fresh signing key asks for another one, and a build that then fails
leaves it behind -- Codemagic only saves its cache after a *successful* build,
so the key is lost and the next build repeats the cycle. Two failures fill both
slots and nothing can be created again.

Apple's API does not report when a certificate was created, but an Apple
Distribution certificate is valid for exactly one year, so creation is its
expiry minus 365 days. Anything created in the last few hours is one of this
build's own leftovers: a certificate a person actually uses was not made in the
window between two CI runs.

    app-store-connect certificates list --type DISTRIBUTION --json \\
        | tools/ios-stale-certs.py 6

Prints one id per line. Silent when there is nothing to clean up.
"""
import datetime
import json
import sys

YEAR = datetime.timedelta(days=365)


def stale_ids(payload, hours: float, now=None):
    now = now or datetime.datetime.now(datetime.timezone.utc)
    cutoff = now - datetime.timedelta(hours=hours)
    found = []
    for entry in payload if isinstance(payload, list) else payload.get("data", []):
        attrs = entry.get("attributes", entry)
        expiry = attrs.get("expirationDate")
        if not expiry:
            continue
        try:
            when = datetime.datetime.fromisoformat(expiry.replace("Z", "+00:00"))
        except ValueError:
            continue
        created = when - YEAR
        # Never touch anything that is not clearly from the last few hours, and
        # never anything dated in the future.
        if cutoff <= created <= now:
            identifier = entry.get("id") or attrs.get("id")
            if identifier:
                found.append(identifier)
    return found


if __name__ == "__main__":
    hours = float(sys.argv[1]) if len(sys.argv) > 1 else 6.0
    try:
        data = json.load(sys.stdin)
    except json.JSONDecodeError:
        sys.exit(0)          # nothing parseable is nothing to clean
    for cert_id in stale_ids(data, hours):
        print(cert_id)
