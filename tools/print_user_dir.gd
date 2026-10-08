extends SceneTree
## Prints this project's user:// directory, for shell scripts that read what
## a capture tool wrote there (tools/make_trailer.sh).
func _init() -> void:
	print(ProjectSettings.globalize_path("user://").trim_suffix("/"))
	quit()
