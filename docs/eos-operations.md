# EOS co-op operations

The production co-op path has no メロスゲーム application server. Devices sign
in with EOS Connect Device ID, discover a two-member EOS Lobby by a six-digit
code, and exchange gameplay through EOS P2P. EOS may use its relay when direct
NAT traversal fails. The old Cloudflare relay is not contacted by the co-op UI.

## Fixed dependency

- EOSG version: `2.3.1`
- Source revision: `56238973e2cd7ac9ac99ca14f88934465f0a8997`
- Installation: `tools/install-eosg.sh`
- Integrity: each platform archive has a pinned SHA-256 in that script

The addon is restored during CI and is intentionally not committed. The
installer also applies one audited patch: EOSG's anonymous helper must retain
the installation's Device ID instead of deleting it at every launch. This
keeps the Product User ID stable enough for lobby rejoin and role recovery.

## Required GitHub secrets

Configure these Actions secrets in the public repository:

- `EOS_PRODUCT_ID`
- `EOS_SANDBOX_ID`
- `EOS_DEPLOYMENT_ID`
- `EOS_CLIENT_ID`
- `EOS_CLIENT_SECRET`

Use a dedicated least-privilege EOS client policy for the shipped game. The
workflow writes an ignored `eos_credentials.json` only on the ephemeral runner.
Android Play signing and iOS App Store signing keep their existing separate
secrets.

## Build and release

Pushes to `main` run `.github/workflows/mobile.yml`, which calls Android and
iOS builds in parallel with Godot 4.7.2. Android produces the normal Vulkan,
Motorola Vulkan and GLES3 test APKs. Google Play remains a manual AAB workflow.
The combined workflow produces the unsigned iOS artifact by default. App Store
submission is an explicit manual option.

Before the five EOS secrets exist, ordinary test builds use clearly invalid
`ci-placeholder-*` values so native packaging can still be verified. Those
artifacts support offline play but cannot create or join online rooms. Android
Play and App Store submission never allow placeholders and fail before a store
artifact is produced.

No local build is required for this integration. Script syntax and repository
checks can run locally, while native Android/iOS compilation belongs to Actions.

## Authority and recovery contract

- Gameplay roles never change: the room creator is runner and the joiner is
  guardian.
- Network authority is the EOS Lobby owner.
- Silence alone never elects a host. Authority changes only after the Lobby's
  `lobby_owner_changed` notification.
- The authority sends a complete, digested migration frame every 250 ms.
- A promoted guardian restores only a fully assembled frame received within
  the previous 500 ms. Otherwise the game stops and asks both players to
  reconnect; it never guesses or creates two authorities.
- After migration, runner input crosses P2P to the guardian-owned simulation.
  A 250 ms input watchdog releases stuck movement if unreliable input stops.

## Release gate

Before calling EOS co-op production-ready, the public workflow must pass and
two physical phones must complete all of the following on different networks:

1. create and join a room;
2. finish stages 1-1 and 1-2 over direct P2P;
3. repeat where EOS reports a relayed connection;
4. background and restore each phone;
5. interrupt the runner's network and verify owner-confirmed migration;
6. verify a state older than 500 ms stops instead of resuming;
7. verify the Astra 3D world on the target Motorola device;
8. verify Android/iOS cross-play with the same protocol/build.

EOS service terms or quotas can change, and store membership, devices and user
data plans are not zero-cost. The architecture removes the game's own
always-on server bill; it does not promise that every external dependency will
remain free forever.
