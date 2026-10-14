# PV promo assets (1-10 PV only)

| file | source |
| --- | --- |
| `badge_google_play.png` | Official "Get it on Google Play" badge (en), downloaded from `play.google.com/intl/en_us/badges/static/images/badges/en_badge_web_generic.png`; transparent margin cropped, scaled to 240px tall. Use per Google Play badge guidelines (unmodified artwork). |
| `badge_app_store.png` | Official "Download on the App Store" badge (US-UK, black), SVG from `developer.apple.com/app-store/marketing/guidelines/`, rasterised with Godot at 6×. Use per Apple's App Store marketing guidelines (unmodified artwork). |
| `discord_mark.png`, `discord_mark_white.png` | Official Discord "Clyde" mark (blurple SVG from Discord's brand assets), rasterised with Godot; the white copy is the same shape recoloured white for use on the blurple call disc. |
| `title_melos_game.png` | `tools/promotion/make_pv_title.py` — set in the project's Baloo 2 Bold (OFL, `assets/fonts`). |
| `you_cursor.png` | `tools/promotion/make_pv_cursor.py` — drawn procedurally. |

New sounds used by 1-10 and the PV (`assets/audio/thunder.wav` … `horn.wav`)
are synthesized by `tools/make_finale_audio.py`; the PV music bed is the
project's own `assets/audio/music_stage.wav` (`tools/make_audio.py`). No
third-party audio is used.
