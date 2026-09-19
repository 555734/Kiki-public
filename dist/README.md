# Downloads

## The current build is on Releases

**[github.com/555734/Kiki-public/releases/latest](https://github.com/555734/Kiki-public/releases/latest)**

`.github/workflows/android.yml` builds both APKs and publishes them there on
every push to the public mirror's `main`. That is the build to install.

## The two files in this directory are an older hand-off copy

They were committed back when Actions could not publish Releases for this
repository, and they have not been rebuilt since — the changelog further down
describes a **two-stage** game, and there are seven stages now. In particular
they predate the painted art for 1-B and 1-S entirely. Keep them only if you
want the build they are; otherwise take the Release above.

| file | renderer | notes |
|---|---|---|
| [**side-sky-vulkan.apk**](https://github.com/555734/Kiki-public/raw/main/dist/side-sky-vulkan.apk) | Vulkan (Godot's "mobile") | Faster on modern hardware |
| [**side-sky-gles3.apk**](https://github.com/555734/Kiki-public/raw/main/dist/side-sky-gles3.apk) | GLES3 (Godot's "compatibility") | Runs on far more devices; often quicker for pure 2D |

They use different package ids, so **both can be installed at once** and
compared on the same device. Open a link on the device itself to download it
directly.

Neither has been run on real hardware — this repository was built in an
environment with no phone attached — so which one performs better on your
device is genuinely an open question. Install both and see.

## Installing

Download the `.apk` on the phone or tablet and open it. Android will warn that
it comes from an unknown source, because these are signed with a self-signed
prototype key rather than a store key; allow the install for your browser or
file manager when prompted. Landscape, two players on one screen.

Verify a download against `SHA256SUMS` if you want to be sure it arrived intact.

## Both phones need the same build

The message format between the two devices carries a version, and a phone with
a mismatched APK cannot play with one running a different build. It does not
fail quietly: the host answers a mismatched build with
**「バージョンが違います」** on the guardian's screen. Update both.

## What changed in the build in this directory

Historical, and kept for the two files above rather than for the current game.

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

## Why these are still committed

They no longer need to be. Actions publishes Releases now, which is the reason
this directory was supposed to be temporary:

> Once it does, delete this directory: keeping binaries in git is a poor habit
> and only worth it while it is the only way to hand over a build.

Deleting them from `HEAD` will not shrink a clone — 60MB of APK is already in
the history and only a history rewrite would remove it — so this is a tidiness
call rather than a size one.
