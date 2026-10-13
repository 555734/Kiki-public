#!/usr/bin/env bash
# Build the trailer from the real game.
#
#   tools/make_trailer.sh /path/to/godot [out.mp4] [-- capture args]
#
# Films every shot (tools/capture_trailer.gd), mixes the soundtrack around a
# score composed to the cut (tools/trailer_mix.py, tools/trailer_music.py),
# encodes 1920x1080 30 fps H.264 + AAC, and next to it writes editor/: every
# shot as a clip, the audio stems and the cut list (tools/trailer_export.py). On Linux
# without a display it runs under xvfb-run; rendering is real OpenGL either
# way, which is why --headless cannot be used.
#
# Extra capture args after `--`, e.g. a quick low-resolution check:
#   tools/make_trailer.sh godot build/trailer/preview.mp4 -- --size 960x540
# A native 9:16 frame with its own cameras and phone layout:
#   tools/make_trailer.sh godot build/trailer/shorts.mp4 -- --portrait
set -euo pipefail
godot="${1:?usage: make_trailer.sh /path/to/godot [out.mp4] [-- capture args]}"
out="${2:-build/trailer/melos_trailer.mp4}"
shift $(( $# >= 2 ? 2 : 1 ))
[ "${1:-}" = "--" ] && shift
here="$(cd "$(dirname "$0")/.." && pwd)"
cd "$here"

run=()
if [ "$(uname)" = "Linux" ] && [ -z "${DISPLAY:-}" ]; then
	run=(xvfb-run -a -s "-screen 0 1280x720x24")
fi
"${run[@]}" "$godot" --path . --rendering-method gl_compatibility \
	--rendering-driver opengl3 --audio-driver Dummy --resolution 640x360 \
	tools/capture_trailer.tscn --fixed-fps 60 -- --ci-skip-eos "$@" \
	| grep -E '^(shot|trailer)'

cap="$("$godot" --headless --path . --quit-after 1 \
	-s tools/print_user_dir.gd 2>/dev/null | grep "^/" | tail -1)/trailer"
# Match capture_trailer.gd's optional output directory.
capture_args=("$@")
for ((i=0; i<${#capture_args[@]}; i++)); do
	if [ "${capture_args[i]}" = "--out" ]; then
		cap="${capture_args[i+1]}"
	fi
done
mkdir -p "$(dirname "$out")"
# Use the exact soundtrack of an existing cut when only reframing it. This
# also preserves effects that were added after the original auto-mix.
if [ -n "${TRAILER_AUDIO_SOURCE:-}" ]; then
	audio="$TRAILER_AUDIO_SOURCE"
	audio_codec=(-c:a copy)
else
	python3 tools/trailer_mix.py "$cap" "$cap/soundtrack.wav"
	audio="$cap/soundtrack.wav"
	audio_codec=(-c:a aac -b:a 192k)
fi
ffmpeg -v error -y -framerate 30 -i "$cap/frames/%05d.png" -i "$audio" \
	-c:v libx264 -preset slow -crf 17 -pix_fmt yuv420p -r 30 \
	-map 0:v:0 -map 1:a:0 "${audio_codec[@]}" -shortest -movflags +faststart "$out"
python3 tools/trailer_export.py "$cap" "$(dirname "$out")/editor"
echo "trailer: $out"
