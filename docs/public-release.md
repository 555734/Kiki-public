# Public repository safety

This project is designed so repository visibility is not a security boundary.
The shipped co-op client uses EOS Lobby/P2P. EOS product, sandbox, deployment
and client identifiers are necessarily present in the app; repository privacy
would not protect values that can be inspected in an APK or network traffic.
The client policy attached to those credentials must therefore be
least-privilege. Private signing keys and store credentials remain secrets.

## Before changing the repository to Public

Run the full repository audit from a local clone:

```bash
tools/audit-public.sh --history
```

The history mode scans every reachable branch/tag commit for high-signal secret
formats and for credential/signing filenames. A failure means **do not change
visibility yet**. Remove or rotate the exposed credential and clean the relevant
history first.

The ordinary form is faster and checks only the current checkout:

```bash
tools/audit-public.sh
```

## Credentials and signing

Real signing material belongs only in GitHub/Codemagic/Apple/Epic secret
stores or local ignored files. `.gitignore` blocks common Apple, Android,
Google, EOS, npm, Python and environment credential formats.

`ci/debug.keystore` is the one intentional exception. It is a public Android
debug key documented in `ci/README.md`; it must never be used as a Play Store
upload/release key.

Team IDs, bundle IDs, EOS product IDs and EOS client IDs are identifiers, not authentication
secrets. Private keys, API tokens, App Store Connect `.p8` files, release
keystores and service-account credentials are secrets.

## Retired Cloudflare path

Co-op production traffic no longer uses the Cloudflare Worker. Its transport
code remains only as a rollback aid, and the separate versus implementation is
hidden from the release UI until it is migrated to EOS. Do not treat the old
Worker as a supported production dependency.

## Legacy relay abuse protection

`server/signaling/worker.js` applies a per-IP connection-attempt limit before a
request reaches a room Durable Object. The default is 30 attempts per minute,
which is far above normal two-player/reconnect traffic but bounds casual abuse
from one source IP. The values can be changed with Worker variables:

- `RATE_LIMIT_MAX`
- `RATE_LIMIT_WINDOW_MS`

This is cost protection, not authentication. Distributed abuse is still
possible, so Cloudflare usage/billing alerts should remain enabled.

## Branches and history

Making a GitHub repository public exposes more than the branch currently being
worked on. Existing branches, tags and reachable history must be treated as
publishable too. Delete obsolete branches only after confirming they are no
longer needed, and run the history audit again afterward.

## Artwork

The current Mario-like artwork/IP question is intentionally **not resolved by
this security pass**. It remains a separate distribution/licensing decision and
should be reviewed before broad public release of the game or its assets.
