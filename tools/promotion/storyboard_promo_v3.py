"""A readable nine-panel storyboard using frames from the delivered movie."""
import subprocess
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/"build/promotion/v3"
MOVIE=OUT/"melos-promo-v3.mp4"
FONT="C:/Windows/Fonts/meiryob.ttc"
panels=[
    (0.9,"00–02秒  追跡者につかまり、突然死ぬ"),
    (3.8,"02–05秒  引いて危険の全景を見せる"),
    (8.6,"08–10秒  助ける側がプレイヤーと判明"),
    (11.15,"10–12秒  失敗した場所へ足場を描く"),
    (13.4,"12–16秒  同じ構図で救助が成功"),
    (16.7,"16–20秒  足場を撃つと相棒が飛ぶ"),
    (23.4,"20–24秒  消えた足場の下で受け止める"),
    (32.9,"24–34秒  5場面、最後は二段射出"),
    (35.0,"34–38秒  タイトルと行動への誘導"),
]
sheet=Image.new("RGB",(1920,1290),(10,19,32))
draw=ImageDraw.Draw(sheet)
font=ImageFont.truetype(FONT,22)
for i,(time,label) in enumerate(panels):
    frame=OUT/f"storyboard-frame-{i+1}.jpg"
    subprocess.run(["ffmpeg","-hide_banner","-loglevel","error","-y","-ss",str(time),"-i",str(MOVIE),"-vf","scale=640:360","-frames:v","1",str(frame)],check=True)
    x,y=(i%3)*640,(i//3)*430
    sheet.paste(Image.open(frame),(x,y))
    draw.text((x+16,y+375),label,font=font,fill="#d9f7ff")
sheet.save(OUT/"storyboard-v3.jpg",quality=94)
print(OUT/"storyboard-v3.jpg",flush=True)
