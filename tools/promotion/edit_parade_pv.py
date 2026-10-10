"""Make the expanded parade trailer from native takes at their recorded speed."""
from __future__ import annotations
import json
import math
import subprocess
import wave
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'build/promotion/stage-1-9/pv-v2'
SR, FPS = 48000, 60
FONT = str(ROOT / 'assets/fonts/Baloo2-Bold.ttf')

def run(args):
    subprocess.run(args, cwd=ROOT, check=True)

def wav(path, audio):
    with wave.open(str(path), 'wb') as f:
        f.setnchannels(2); f.setsampwidth(2); f.setframerate(SR)
        f.writeframes((np.clip(audio, -1, 1)*32767).astype('<i2').tobytes())

def soundtrack(duration, music_at, clips, events):
    """Original 150 BPM mechanical carnival score and event-timed sound design."""
    rng = np.random.default_rng(1910)
    a = np.zeros((round(duration*SR), 2), dtype=np.float64)
    def add(signal, at, gain, pan=0):
        pos = round(at*SR)
        if pos < 0 or pos >= len(a): return
        signal = signal[:len(a)-pos]*gain
        a[pos:pos+len(signal),0] += signal*math.sqrt((1-pan)/2)
        a[pos:pos+len(signal),1] += signal*math.sqrt((1+pan)/2)
    def tone(midi, length=.28, brass=False):
        t = np.arange(round(length*SR))/SR
        f = 440*2**((midi-69)/12)
        signal = np.sin(2*np.pi*f*t)
        for h in range(2, 7 if brass else 3):
            signal += np.sin(2*np.pi*h*f*t)*(0.45**(h-1) if brass else .16)
        envelope = (1-np.exp(-180*t))*np.exp(-(7 if brass else 10)*t)
        return signal*envelope
    t = np.arange(round(.24*SR))/SR
    kick = np.sin(2*np.pi*(48*t+105*(1-np.exp(-35*t))/35))*np.exp(-18*t)
    t = np.arange(round(.17*SR))/SR
    noise = rng.standard_normal(len(t))
    snare = (noise-np.convolve(noise,np.ones(12)/12,mode='same'))*np.exp(-35*t)
    t = np.arange(round(.05*SR))/SR
    hat = rng.standard_normal(len(t))*np.exp(-90*t)
    beat=.4
    roots=[38,34,43,45]
    motif=[74,77,81,77,74,72,69,73,74,77,79,81,79,77,76,73]
    length=duration-music_at
    for i in range(math.ceil(length/beat)):
        at=music_at+i*beat
        root=roots[(i//4)%4]
        add(kick,at,.24)
        add(tone(root,.33),at,.14)
        if i%4 in (1,3): add(snare,at,.095)
        for j in range(4): add(hat,at+j*.1,.025, .35 if j%2 else -.35)
        add(tone(motif[i%16],.3,True),at,.07,-.2)
        if i%2==1: add(tone(motif[(i+3)%16]+12,.17),at+.2,.035,.3)
        if i%16==15:
            for j in range(3): add(snare,at+j*.1,.025*(j+1))
    by_name={c['take']:c for c in clips}
    def moment(e):
        c=by_name[e['take']]
        return c['timeline_start']+(e['frame']-1)/FPS-c['start']
    # A low impact and a pull-back swish lead into the crowd reveal.
    bite=next(e for e in events if e['event']=='bite')
    at=moment(bite)
    add(kick,at,.65)
    t=np.arange(round(.7*SR))/SR
    add(rng.standard_normal(len(t))*np.exp(-8*t)*.14+np.sin(2*np.pi*32*t)*np.exp(-6*t),at,.3)
    t=np.arange(round(.58*SR))/SR
    swish=rng.standard_normal(len(t))*np.sin(np.pi*t/.58)**2
    swish=np.convolve(swish,np.ones(5)/5,mode='same')
    add(swish,at+.18,.16)
    for c in clips:
        if c['timeline_start']>=music_at and c['take']!='title':
            add(kick,c['timeline_start'],.12)
    for e in events:
        if e['take'] not in by_name: continue
        if e['event']=='shot':
            at=moment(e)
            t=np.arange(round(.13*SR))/SR
            add(np.sin(2*np.pi*(160*t+450*t*t))*np.exp(-35*t),at,.17)
        if e['event'] in ['crowd_launch','flight','stairs']:
            add(kick,moment(e),.25)
    title_at=by_name['title']['timeline_start']
    # Thin the rhythm under the end card and resolve a D minor chord.
    start=round((title_at+.8)*SR)
    a[start:] *= np.linspace(1,.15,len(a)-start)[:,None]
    for note in [50,57,62,65,69]: add(tone(note,2.1,True),title_at+1.1,.055)
    tail=round(.3*SR)
    a[-tail:]*=np.linspace(1,0,tail)[:,None]
    wav(OUT/'original-score.wav',np.tanh(a)*.65)

def edit():
    meta=json.loads((OUT/'takes.json').read_text(encoding='utf-8'))
    events={(e['take'],e['event']):e['detail'] for e in meta['events']}
    checks={
        'bite_before_two_seconds': events['bite_reveal','bite']['dead'] and events['bite_reveal','bite']['seconds']<=2 and events['bite_reveal','bite']['cause']=='parade',
        'real_bridge_crossing': all(events['partner_bridge','bridge_crossed'][k] for k in ['alive','open','crossed']),
        'jaw_changes_outcome': events['jaw_reversal','reversal']['closed'] and events['jaw_reversal','reversal']['new_kills']>=1,
        'fourteen_native_crowd_launches': events['accordion','crowd_launch']['flying']>=14,
        'curtain_carries_runner': events['curtain','ride']['alive'] and events['curtain','ride']['rise']>70,
        'magnet_release': events['magnet','released']['active'],
        'stilt_becomes_ramp': events['stilt','folded']['ramp'],
        'cannon_crosses_gap': all(events['cannon','gap_crossed'][k] for k in ['crossed','alive']) and events['cannon','fired']['cannon_launch'],
        'shadow_becomes_prop': events['shadow','safe_shadow']['prop'],
        'hound_opens_stairs': events['hound','stairs']['broken'],
        'real_gondola_ride': events['wheel','gondola']['alive'] and events['wheel','gondola']['rise']>60,
        'drawn_platform_catches_runner': events['final_rescue','catch']['alive'] and events['final_rescue','catch']['loaded'],
        'native_launch_and_goal': events['final_rescue','flight']['airborne'] and events['final_rescue','goal']['cleared'],
        'all_recorded_shots_hit': all(e['detail']['hit'] for e in meta['events'] if e['event']=='shot' and e['take']!='setup'),
        'runner_survives_every_take_after_opening': all(s['runner_alive'] for s in meta['segments'] if s['name']!='bite_reveal'),
    }
    (OUT/'capture-checks.json').write_text(json.dumps(checks,indent=2),encoding='utf-8')
    assert all(checks.values()),checks
    cursor=0.;clips=[]
    for s in meta['segments']:
        duration=(s['end_frame']-s['start_frame'])/FPS
        clips.append(dict(take=s['name'],start=(s['start_frame']-1)/FPS,end=(s['end_frame']-1)/FPS,duration=duration,timeline_start=cursor,speed=1.0))
        cursor+=duration
    total=round(cursor*FPS)/FPS
    timeline={c['take']:c for c in clips}
    music_at=timeline['accordion']['timeline_start']
    soundtrack(total,music_at,clips,meta['events'])
    layers=[]
    def save(name,im,start,end):
        p=OUT/('overlay-'+name+'.png');im.save(p);layers.append((p,start,end))
    def caption(name,words,start,end):
        im=Image.new('RGBA',(1280,720));d=ImageDraw.Draw(im)
        font=ImageFont.truetype(FONT,40)
        x=1230-d.textlength(words,font=font)
        d.text((x,26),words,font=font,fill='#ffe08a',stroke_width=4,stroke_fill='#192b3e')
        save(name,im,start,end)
    im=Image.new('RGBA',(1280,720));d=ImageDraw.Draw(im)
    # Original portraits: the reveal identifies the existing second character.
    for name,x,label,action,color in [('lira',42,'PLAYER 1','RUN','#ffdf86'),('orion',962,'PLAYER 2','SHOOT','#a4faff')]:
        portrait=Image.open(ROOT/f'assets/ui/portrait_{name}.png').convert('RGBA')
        portrait.thumbnail((104,104),Image.Resampling.LANCZOS)
        d.rounded_rectangle((x,28,x+276,150),radius=18,fill=(14,25,40,205),outline=color,width=2)
        im.alpha_composite(portrait,(x+6,37))
        d.text((x+116,38),label,font=ImageFont.truetype(FONT,23),fill='white')
        d.text((x+116,76),action,font=ImageFont.truetype(FONT,35),fill=color)
    bridge=timeline['partner_bridge']['timeline_start']
    save('roles',im,bridge+.14,bridge+2.5)
    caption('spring','ONE SHOT. FOURTEEN FLY.',music_at+.2,music_at+1.85)
    rescue=timeline['final_rescue']['timeline_start']
    caption('rescue','DRAW. SHOOT. SOAR.',rescue,total-3.2)
    # Native goal and successful runner remain visible on the right.
    rgba=np.zeros((720,1280,4),dtype=np.uint8);rgba[:,:,:3]=(13,23,39)
    rgba[:,:,3]=np.clip(246*(1-np.arange(1280)/1190),0,246).astype(np.uint8)[None,:]
    im=Image.fromarray(rgba);d=ImageDraw.Draw(im)
    d.line((62,210,194,210),fill='#9bf9fb',width=5)
    for words,xy,size,color in [
        ('MELOS GAME',(57,235),93,'#ffffff'),
        ('THE TRICKSTER PARADE',(62,361),40,'#ffdf86'),
        ('BY Inoue and Sasabe',(62,431),32,'#ffffff'),
        ('PLAY TOGETHER',(62,517),39,'#a4faff')]:
        d.text(xy,words,font=ImageFont.truetype(FONT,size),fill=color)
    save('title',im,timeline['title']['timeline_start'],total)
    graph=[];pairs=[]
    for i,c in enumerate(clips):
        graph.append(f"[0:v]trim=start={c['start']:.9f}:end={c['end']:.9f},setpts=PTS-STARTPTS,fps=60,setsar=1,scale=1280:720:in_range=pc:out_range=tv:in_color_matrix=bt601:out_color_matrix=bt709,format=yuv420p,setparams=range=limited:colorspace=bt709:color_primaries=bt709:color_trc=bt709[v{i}]")
        graph.append(f"[0:a]atrim=start={c['start']:.9f}:end={c['end']:.9f},asetpts=PTS-STARTPTS,apad,atrim=duration={c['duration']:.9f}[a{i}]")
        pairs.append(f'[v{i}][a{i}]')
    graph.append(''.join(pairs)+f'concat=n={len(clips)}:v=1:a=1[base][sfx]')
    last='base'
    for i,(_,a,b) in enumerate(layers,start=2):
        graph.append(f'[{i}:v]format=rgba,fade=t=in:st={a:.6f}:d=0.08:alpha=1,fade=t=out:st={b-.08:.6f}:d=0.08:alpha=1[g{i}]')
        graph.append(f"[{last}][g{i}]overlay=enable='between(t,{a:.6f},{b:.6f})':eof_action=repeat[o{i}]")
        last=f'o{i}'
    graph.append(f'[{last}]fps=60,format=yuv420p[vout]')
    graph.append(f'[1:a]apad,atrim=duration={total},volume=.85[score]')
    graph.append(f'[sfx]volume=.65[sounds]')
    graph.append(f'[sounds][score]amix=inputs=2:duration=first:normalize=0,loudnorm=I=-16:TP=-3:LRA=11,aresample=48000,afade=t=out:st={total-.25}:d=0.25[aout]')
    filt=OUT/'edit-filter.txt';filt.write_text(';\n'.join(graph),encoding='utf-8')
    (OUT/'edit-timeline.json').write_text(json.dumps(clips,indent=2),encoding='utf-8')
    (OUT/'edit-plan.json').write_text(json.dumps(dict(duration=total,fps=60,resolution=[1280,720],english_only=True,creator='Inoue and Sasabe',music_start=music_at,original_music=True,gameplay_speed=1.0,stage='1-9'),indent=2),encoding='utf-8')
    movie=OUT/'melos-trickster-parade-pv.mp4'
    args=['ffmpeg','-hide_banner','-loglevel','warning','-y','-i',str(OUT/'raw-takes.avi'),'-i',str(OUT/'original-score.wav')]
    for p,_,_ in layers: args+=['-loop','1','-framerate','60','-i',str(p)]
    args+=['-filter_complex_threads','2','-filter_complex_script',str(filt),'-map','[vout]','-map','[aout]','-t',str(total),'-c:v','libx264','-crf','18','-preset','medium','-pix_fmt','yuv420p','-r','60','-fps_mode','cfr','-colorspace','bt709','-color_primaries','bt709','-color_trc','bt709','-c:a','aac','-b:a','192k','-movflags','+faststart',str(movie)]
    run(args)
    run(['ffmpeg','-hide_banner','-loglevel','error','-y','-i',str(movie),'-vf','fps=2,scale=384:216,tile=6x10','-frames:v','1',str(OUT/'contact.jpg')])
    print(json.dumps(dict(movie=str(movie),duration=total)))

if __name__=='__main__': edit()
