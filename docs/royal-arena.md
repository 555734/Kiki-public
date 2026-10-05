# Royal Arena

Royal Arena is the default for solo practice, hosting and versus stage selection.
The five previous arenas remain selectable. Cooperative stages are unchanged.
The new stage ID is 13, appended after CAVE to preserve network IDs.

The 3200 px looping arena mirrors every solid, spring and moving platform.
Ground spans heights 240–400, with 140 px gaps and steps at most 80 px.
Seven upper platforms provide alternative routes. Springs on each side and
Clock-driven mirrored lifts connect the upper tier and central contest area.
Random stars use the existing collision-aware spawn rules. Existing enemy,
shooting, respawn and rematch rules apply.

Runtime artwork comes from the owner-supplied Royal Arena ZIP: sky kingdom
background, main and side platforms, floating platforms, red flags, planters,
pillars, banners and crests. Blue hologram art is used for player-built platforms.
Remaining pack variants are available in Art for future changes. PNG painting
shares the collision rectangles used by the host and clients; gold lips mark
the precise platform tops.

Validation: versus_probe checks every arena for symmetry, reachable rows,
safe spawn points, deterministic enemies and conserved stars; versus_reach_probe
physically jumps both ways over every floor transition. Versus touch/team probes
exercise the default arena over loopback, including mobile input, shooting,
platform construction and rematches. Legacy play/net fixtures explicitly select
Greenfield because their geometric assertions reference its coordinates.
