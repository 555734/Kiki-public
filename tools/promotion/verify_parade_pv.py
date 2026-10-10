"""Verify the exported trailer, real native payoffs and original asset hashes."""
import hashlib
import json
import re
import subprocess
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'build/promotion/stage-1-9/pv-v2'

def verify():
    movie=OUT/'melos-trickster-parade-pv.mp4'
    info=json.loads(subprocess.check_output(['ffprobe','-v','error','-count_frames','-show_streams','-show_format','-of','json',str(movie)],text=True))
    (OUT/'export-info.json').write_text(json.dumps(info,indent=2),encoding='utf-8')
    video=next(s for s in info['streams'] if s['codec_type']=='video')
    audio=next(s for s in info['streams'] if s['codec_type']=='audio')
    assert (video['width'],video['height'],video['codec_name'],video['avg_frame_rate'])==(1280,720,'h264','60/1')
    assert audio['codec_name']=='aac' and int(audio['sample_rate'])==48000 and video['color_space']=='bt709'
    plan=json.loads((OUT/'edit-plan.json').read_text(encoding='utf-8'))
    assert abs(float(info['format']['duration'])-plan['duration'])<.025
    assert int(video['nb_read_frames'])==round(plan['duration']*60)
    decoded=subprocess.run(['ffmpeg','-hide_banner','-v','error','-i',str(movie),'-f','null','-'],check=True,capture_output=True)
    assert not decoded.stderr,decoded.stderr
    checks=json.loads((OUT/'capture-checks.json').read_text(encoding='utf-8'))
    assert len(checks)==15 and all(checks.values()),checks
    meta=json.loads((OUT/'takes.json').read_text(encoding='utf-8'))
    for row in meta['frame_metrics']:
        x,y=row['runner_screen']
        assert 32<=x<=1248 and 32<=y<=688,row
    timeline=json.loads((OUT/'edit-timeline.json').read_text(encoding='utf-8'))
    assert all(c['speed']==1 for c in timeline)
    imports=json.loads((OUT/'import-baseline.json').read_text(encoding='utf-8'))
    for rel,digest in imports.items(): assert hashlib.sha256((ROOT/rel).read_bytes()).hexdigest()==digest,rel
    heroes=json.loads((ROOT/'docs/promotion/parade-artbook-v2/hero-reference-hashes.json').read_text(encoding='utf-8'))
    for row in heroes: assert hashlib.sha256((ROOT/row['source']).read_bytes()).hexdigest()==row['sha256'],row['source']
    loud_log=subprocess.run(['ffmpeg','-hide_banner','-nostats','-i',str(movie),'-af','loudnorm=I=-16:TP=-1:LRA=11:print_format=json','-f','null','-'],check=True,capture_output=True,text=True).stderr
    loud=json.loads(re.findall(r'\{\s*"input_i".*?\}',loud_log,re.S)[-1])
    assert float(loud['input_tp'])<=-.7,loud
    (OUT/'loudness-check.json').write_text(json.dumps(loud,indent=2),encoding='utf-8')
    # Compare the meaningful physics outcomes with the independent headless run.
    probe=json.loads((OUT/'takes-probe.json').read_text(encoding='utf-8'))
    for field in ['bite','bridge_crossed','crowd_launch','ride','fired','gap_crossed','gondola','catch','flight','goal']:
        a=next(e['detail'] for e in meta['events'] if e['event']==field)
        b=next(e['detail'] for e in probe['events'] if e['event']==field)
        assert a==b,(field,a,b)
    report=dict(duration=float(info['format']['duration']),frames=int(video['nb_read_frames']),resolution=[1280,720],fps=60,
        native_outcomes_checked=len(checks),full_decode='passed',framed_frames=len(meta['frame_metrics']),
        gameplay_speed=1.0,imports_preserved=len(imports),original_character_files_preserved=len(heroes),
        lufs=float(loud['input_i']),true_peak_db=float(loud['input_tp']),
        english_only=plan['english_only'],creator=plan['creator'],original_music=True,
        git_base='ff1607e',source='native Godot gameplay; directed camera and player inputs',
        runtime_exit_resource_warning='two resources retained at engine exit; no script errors during capture')
    (OUT/'verification.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    print(json.dumps(report))

if __name__=='__main__': verify()
