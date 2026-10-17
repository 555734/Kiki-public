#!/bin/bash
# Record PV takes: record_take.sh TAKE[,TAKE...] -> build/promotion/stage-1-10/pv/takes.avi + shots_report.json.
# VIEW_H=1156 records a taller view (VIEW_W x VIEW_H, VIEW_W default 1280) through a temporary override.cfg.
# GODOT=path to the Godot 4.7 binary (default: godot on PATH).
cd "$(dirname "$0")/../.."
G=${GODOT:-godot}
OUT=build/promotion/stage-1-10/pv
rm -f $OUT/takes.avi
RES=1280x720
if [ -n "$VIEW_H" ]; then
  printf '[display]\n\nwindow/size/viewport_width=%s\nwindow/size/viewport_height=%s\n' ${VIEW_W:-1280} $VIEW_H > override.cfg
  RES=${VIEW_W:-1280}x$VIEW_H
fi
timeout 1500 xvfb-run -a -s "-screen 0 1400x1200x24" $G --path . --rendering-method gl_compatibility --rendering-driver opengl3 --fixed-fps 60 --resolution $RES --write-movie $OUT/takes.avi res://tools/promotion/capture_finale_pv.tscn -- --take=$1 > ${TAKE_LOG:-/tmp/take.log} 2>&1
rm -f override.cfg
grep -E "SHOT|->|ERROR|SCRIPT|Parse|error|cuts pass|stairs|ramp_planned" ${TAKE_LOG:-/tmp/take.log} | grep -v ALSA | head -80
