# Downloads

Two builds of the same game, built and signed from this repository.
They use different package ids, so **both can be installed at once** and
compared on the same device.

| file | renderer | notes |
|---|---|---|
| [**side-sky-vulkan.apk**](https://github.com/555734/Kiki/raw/refs/heads/claude/coop-platformer-game-pfgass/dist/side-sky-vulkan.apk) | Vulkan (Godot's "mobile") | Faster on modern hardware |
| [**side-sky-gles3.apk**](https://github.com/555734/Kiki/raw/refs/heads/claude/coop-platformer-game-pfgass/dist/side-sky-gles3.apk) | GLES3 (Godot's "compatibility") | Runs on far more devices; often quicker for pure 2D |

Open a link on the device itself to download it directly. If this repository is
private you will need to be signed in to GitHub on that device.

Neither has been run on real hardware — this repository was built in an
environment with no phone attached — so which one performs better on your
device is genuinely an open question. Install both and see.

## Installing

Download the `.apk` on the phone or tablet and open it. Android will warn that
it comes from an unknown source, because these are signed with the repository's
committed debug key rather than a store key; allow the install for your browser
or file manager when prompted. Landscape, two players on one screen.

Verify a download against `SHA256SUMS` if you want to be sure it arrived intact.

## What changed in this build

**A second stage, and it is the one the game opens on.** 1-C "THE CROSSING" is
about three minutes long and cannot be finished alone: every section has one
thing in it that a single player has no answer to. A step nothing jumps, a gap
nothing crosses, a shelf that needs a wall to kick off, a crossing that needs a
launch, two shield-bearers that need the runner to turn them round, and then all
of it at once. 1-1 is still here and still complete.

**The launch is worth taking now.** It used to carry the runner 349px; one
player sprinting into a jump with the air dash spent goes 326px. The move that
costs the guardian a platform and a shot, and needs both players to set it up,
was worth twenty-three pixels. Air control was dragging the launch's speed back
to a walk within a tenth of a second. It carries 679px now, measured.

**Two things that were broken on the guardian's screen only.** A platform that
had already been fired still looked ready to fire. And a shield-bearer's soft
spot and its shield were drawn on opposite sides of it while their hit areas sat
stacked in the middle — so every shot the guardian aimed into the opening the
runner had just made was eaten by the shield, and from that side the enemy could
not be killed at all. Both are fixed, and both were found by running the game as
two processes against a real relay for the first time.

## Both phones need this build

The message format between the two devices changed again in this build (the
handshake now carries which device each player is, not only which version they
are running), so a phone with an older APK cannot play with a phone running this
one. It will not fail quietly: the host answers a mismatched
build with **「バージョンが違います」** on the guardian's screen. Update both.

## Why these are committed rather than attached to a Release

A GitHub Release is the right home for a binary, and `.github/workflows/
android.yml` is written to build both APKs and publish exactly that. It cannot
run yet: the workflow is registered and active, but every run is killed within
seconds before a runner starts, which is what GitHub Actions being unavailable
for the repository looks like (commonly a billing or spending-limit setting on
a private repo). Enable Actions for the repository and the workflow will take
over — it runs on a push to the working branch, on a `v*` tag, or from the
Actions tab.

Once it does, delete this directory: keeping binaries in git is a poor habit
and only worth it while it is the only way to hand over a build.
