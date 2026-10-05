# Public content and quality integration

PR #1 now includes public main through 4b0f45b (0.9.7). The conflict resolution
preserves split art, the molten 1-5 and horizontal desert 1-6, distant 1-7/1-8
backgrounds, delayed themed pursuers, floating controls and the default Royal
Arena. Stage IDs remain stable; Royal Arena is 13 and versus protocol 11.

The PR's decomposed input, menu and versus components, complete test manifest,
exact failure checks, server tests, pinned build dependencies, store rehearsal,
release safety and render batching remain. Floating ownership is implemented
in StickGesture/TouchRouter, rather than bringing the monolithic InputHub back.
Art texture data is separated into common, stage 1-2 through 1-8 and Royal Arena
manifests. Shared entities bind a visual style once at construction; they no
longer branch on the live stage for their painting. The stage-read ceiling was
reduced from 35 to 4 (the goal's remaining data lookups).

Legacy coordinate-based logic fixtures explicitly exercise custom fixed sticks;
the default floating layout is independently gated by floating_controls_probe
(90 checks), real viewport-versus touch probes and the Royal Arena probe.
World-tap fixtures pan targets clear of the enlarged control zones. Pursuer
checks advance the runner past activation before checking pursuit. Swamp and
desert probes describe the layouts currently shipped, rather than the PR's
unreleased alternative climbs. No failures are added to known_failures.txt.

Local 1280x720 GL peak draw calls after integration:

| Stage | Peak draw calls | Peak objects |
| --- | ---: | ---: |
| 1-1 | 82 | 2717 |
| 1-2 | 97 | 2644 |
| 1-3 | 88 | 3389 |
| 1-4 | 112 | 2675 |
| 1-5 | 114 | 2557 |
| 1-6 | 60 | 2661 |
| 1-7 | 84 | 3127 |
| 1-8 | 38 | 3071 |

The previous 1-5 figure of 513 described a different, unreleased vertical
layout. The shipped molten crossing already falls below 300 with the PR's
culling; its gate is reduced to 300. Object budgets are recalibrated from these
measurements with about 10% headroom because the current art/manifests add
resources to the previous content baseline. Frame times are machine-specific
and are not evidence of mobile performance.

Device acceptance remains a distinct requirement: Android/iPhone interoperability,
background return, network changes, purchases/restores, notches and sustained
play must be recorded on real devices using docs/release-acceptance.md.

Purchase scope preserves public main: 1-6 through 1-8 remain free. The purchase
screen, listing, support page, entitlement probe and release gate agree on paid
stages 1-3 through 1-5. This integration does not change the sold product.
