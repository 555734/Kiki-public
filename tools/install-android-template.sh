#!/usr/bin/env bash
# Install Godot's bundled Android Gradle source template without starting the
# editor main loop. This is deterministic in headless CI and matches the
# `res://android/build` layout produced by the editor command.
set -euo pipefail

cd "$(dirname "$0")/.."

GODOT="${GODOT:-godot}"
if [ -n "${GODOT_VERSION:-}" ]; then
	template_version="${GODOT_VERSION}.stable"
else
	engine_version="$("$GODOT" --version | head -n 1)"
	template_version="${engine_version%%.official.*}"
fi

template_root="${GODOT_TEMPLATE_ROOT:-${HOME}/.local/share/godot/export_templates/${template_version}}"
template_zip="${template_root}/android_source.zip"
if [ ! -f "$template_zip" ]; then
	echo "Android source template not found: $template_zip" >&2
	exit 1
fi

mkdir -p android/build android/plugins
unzip -q -o "$template_zip" -d android/build
printf '%s\n' "$template_version" > android/.build_version
touch android/build/.gdignore
chmod +x android/build/gradlew
echo "Installed Android Gradle template ${template_version}"
