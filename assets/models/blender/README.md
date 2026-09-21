# Lira mobile model

`tools/blender/lira_mobile.blend` is the editable Blender 4.5 LTS source.  The model follows
the existing painted runner: chestnut hair, red scarf, cream shirt, blue
overalls, brown gloves and boots.  It has one armature and eight compact actions
(`Idle`, `Run`, `Jump`, `Fall`, `Land`, `Dash`, `Hurt`, `Dead`).

`assets/models/blender/lira_mobile.glb` is the runtime export used by Godot.  It uses flat PBR
materials and no texture images.  The game renders it in one transparent
viewport at at most 720 pixels wide, without MSAA or shadows.  Everything except
the controllable characters remains on the original 2D canvas.

Regenerate both files from the repository root:

```powershell
blender --background --factory-startup --python tools/blender/build_lira_mobile.py
```
