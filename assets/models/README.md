# Kiki original 3D asset library

These are real, vertex-coloured polygon meshes, authored specifically for Kiki.
LIRA retains her chestnut hair and red scarf, with an ochre field jacket and
indigo trousers. Enemies use a carved carapace / mechanical creature vocabulary;
they are not traced or extracted from another game's models.

The runtime uses the recipes in `src/render/three/`. The `.scn` files are compact,
editable **rest-pose prefabs** made from those exact recipes. They contain actual
meshes and the articulated node hierarchy, not rendered pictures. Their animation
controllers live in `lira.gd` and `enemy_model.gd`. Editing a prefab alone does not
change the runtime recipe; update the recipe and regenerate this library.

Regenerate with Godot 4.4.1 from the repository root:

```sh
godot --headless --path . res://tools/export_three_assets.tscn
```

Inspect the animated library using a real rendering driver:

```sh
godot --path . res://test/three_gallery.tscn
```

`manifest.json` records triangles and mesh parts for each prefab. Terrain in the
game is generated from the existing stage slabs, split into at most 512px chunks;
the terrain prefab is a sample of that generator. Stage palettes are selected
from the current stage, and team costumes are generated from team colours.

No Blender installation, external texture pack, skeleton importer, or 3D physics
engine is required. The source recipes are the reproducible modelling files.
