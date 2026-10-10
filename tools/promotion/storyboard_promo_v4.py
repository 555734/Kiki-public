"""Nine actual frames from V4, with English captions outside the footage."""
import subprocess
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/"build/promotion/v4"
MOVIE=OUT/"melos-promo-v4.mp4"
panels=[
    (1.10,"01.10  CAUGHT"),
    (2.90,"02.90  THE COURSE REVEALED"),
    (4.25,"04.25  NO ONE TO CATCH YOU"),
    (5.30,"05.30  YOU DRAW THE WAY"),
    (5.65,"05.65  SAVED"),
    (7.25,"07.25  LAND. LAUNCH. REPEAT."),
    (11.55,"11.55  STOP THE CHASER"),
    (18.00,"18.00  KEEP EACH OTHER ALIVE"),
    (24.00,"24.00  MELOS GAME"),
]
sheet=Image.new("RGB",(1920,1260),(10,19,32))
draw=ImageDraw.Draw(sheet)
font=ImageFont.truetype(str(ROOT/"assets/fonts/Baloo2-Bold.ttf"),27)
for i,(time,label) in enumerate(panels):
    frame=OUT/f"storyboard-frame-{i+1}.jpg"
    subprocess.run(["ffmpeg","-hide_banner","-loglevel","error","-y","-ss",str(time),"-i",str(MOVIE),"-vf","scale=640:360","-frames:v","1",str(frame)],check=True)
    x,y=(i%3)*640,(i//3)*420
    with Image.open(frame) as image: sheet.paste(image,(x,y))
    draw.text((x+16,y+371),label,font=font,fill="#d9f7ff")
sheet.save(OUT/"storyboard-v4.jpg",quality=94)
print(OUT/"storyboard-v4.jpg",flush=True)
