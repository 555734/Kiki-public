extends Node
## Loads every GDScript and shader under src/ and test/ so an error anywhere
## fails the check, not only in files the main scene happens to reach.
##
## Runs as a scene rather than via --script, because GDScript only resolves
## autoload names like `Balance` and `Events` once the autoloads exist, which a
## bare SceneTree script never creates.
##
## Detection is deliberately split in two: this script catches files that fail
## to produce a resource, and tools/verify.sh greps the engine's stderr for
## "SCRIPT ERROR", which is where parse errors on already-cached scripts land.
## Re-parsing in-use scripts with CACHE_MODE_IGNORE segfaults the engine, so we
## do not try to be cleverer than this.

func _walk(dir_path: String, out: Array) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var full := dir_path.path_join(entry)
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_walk(full, out)
		elif entry.ends_with(".gd") or entry.ends_with(".gdshader"):
			out.append(full)
		entry = dir.get_next()
	dir.list_dir_end()

func _ready() -> void:
	var files: Array = []
	_walk("res://src", files)
	_walk("res://test", files)
	files.sort()
	var failed: Array[String] = []
	for f in files:
		var res: Resource = load(f)
		if res == null:
			failed.append(f)
		elif res is GDScript and not (res as GDScript).can_instantiate():
			# A script whose parse failed is handed back from cache as an
			# invalid GDScript rather than as null, so ask whether it is usable.
			failed.append(f + "  (parse failed)")
		elif res is Shader and (res as Shader).code.strip_edges().is_empty():
			failed.append(f + "  (empty shader)")
	print("--- script check: %d files, %d failed ---" % [files.size(), failed.size()])
	for f in failed:
		print("  FAIL  ", f)
	get_tree().quit(0 if failed.is_empty() else 1)
