"""Cut the owner's 1-6..1-8 boards into runtime sprites (Pillow required).

Coordinates deliberately exclude labels, panel borders and demonstration actors.
Opaque panels are keyed using their dark blue/purple backdrop; bright artwork
and effects are preserved. Originals stay in the supplied zip, not the export.
Usage: python tools/integrate_late_stage_assets.py path/to/pack.zip
"""
from pathlib import Path
from zipfile import ZipFile
import sys
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
PREFIX = 'Kiki_stage_1-6_to_1-8_split/'
# (name, left, top, right, bottom), in original board pixels.
CROPS = {
 '1-6/background/background_assets.png': [
  ('ground',32,86,298,210), ('stone',808,97,923,210),
  ('column',27,226,166,453), ('broken_column',176,296,365,454),
  ('arch',371,226,642,454), ('broken_arch',645,224,857,455),
  ('rubble',1006,290,1436,455)],
 '1-6/gimmicks/gimmicks.png': [
  ('bridge',26,0,316,90), ('lift',514,0,741,85),
  ('crumble',749,0,950,82), ('conveyor',1156,0,1438,88),
  ('spring',37,184,166,290), ('updraft',443,98,603,295),
  ('switch_off',606,195,751,270), ('switch_on',760,132,909,285),
  ('gate',930,108,1183,271), ('spikes',39,329,190,394),
  ('checkpoint_off',578,278,731,455), ('checkpoint_on',731,280,897,455),
  ('key',912,326,1008,447), ('crystal',1035,302,1124,452),
  ('goal',1176,271,1440,475), ('palm',17,398,279,585),
  ('palm_small',278,455,411,576), ('bush',413,465,554,577),
  ('grass',763,484,882,573), ('rocks',885,478,1168,574)],
 '1-7/background/background_assets.png': [
  ('ground',2,102,110,184), ('platform',111,121,180,176),
  ('wall',182,23,261,188), ('window',268,23,402,190),
  ('clock',498,23,706,193), ('gear',712,36,849,182),
  ('chain',939,32,970,194), ('banner',985,34,1069,189),
  ('lamp',1074,31,1132,175), ('column',1191,21,1277,195)],
 '1-7/enemies/enemies.png': [
  ('turret_idle',14,108,73,208), ('turret_alert',84,108,147,208),
  ('turret_fire',158,111,240,208), ('turret_broken',242,144,312,208),
  ('mine_idle',336,110,399,197), ('mine_alert',399,109,468,197),
  ('mine_attack',468,97,548,198)],
 '1-7/gimmicks/gimmicks.png': [
  ('lift',38,59,151,105), ('clock_hand',180,53,356,105),
  ('blink',373,60,465,106), ('crumble',481,54,584,107),
  ('conveyor',602,57,743,107), ('updraft',768,27,847,114),
  ('pendulum',27,159,86,256), ('pendulum_ball',27,208,86,256),
  ('piston',119,160,163,258), ('piston_head',119,229,163,258),
  ('spikes',190,160,234,258), ('warp',248,158,328,257),
  ('warp_exit',346,159,418,258), ('switch',439,175,506,260),
  ('gate',516,158,612,260), ('gear',628,170,701,253),
  ('spring',730,180,788,255), ('rail',811,158,850,260)],
 '1-8/background/background_assets.png': [
  ('ground',4,50,141,144), ('platform',214,44,344,115),
  ('stalactite',393,20,471,144), ('wall',603,17,700,145),
  ('crystal',773,22,848,89), ('crystal_small',851,50,902,89),
  ('lamp',925,25,998,145), ('bridge',1022,38,1142,145),
  ('waterfall',1151,22,1241,145), ('distant',1246,25,1398,144)],
 '1-8/enemies/enemies.png': [
  ('burrower_idle',105,101,192,155), ('burrower_rise',194,76,285,155),
  ('slime_idle',324,101,390,153), ('slime_move',409,112,495,153),
  ('slime_jump',504,72,574,143), ('mushroom_idle',615,89,680,153),
  ('mushroom_move',687,81,752,153), ('mushroom_jump',759,99,824,155),
  ('bat_idle',846,80,934,142), ('bat_move',937,90,1012,153),
  ('bat_attack',1013,68,1123,142), ('beetle_idle',1151,95,1232,153),
  ('beetle_move',1238,95,1322,153), ('beetle_attack',1327,83,1405,153)],
 '1-8/gimmicks/gimmicks.png': [
  ('lift',50,99,149,158), ('blink',417,96,489,132),
  ('crumble',578,95,652,135), ('conveyor',749,94,877,151),
  ('updraft',915,91,1008,161), ('switch',1048,91,1127,151),
  ('switch_bridge',1162,121,1281,159), ('boulder',416,207,543,294),
  ('stalactite',578,197,634,294), ('spring',743,230,817,294),
  ('key',871,219,906,287), ('goal',969,202,1042,294),
  ('checkpoint',1118,213,1170,294), ('crystal',1227,220,1296,294),
  ('rail',9,206,291,294)],
}
# Desert frames have genuine alpha. Isolate neighboring poses explicitly.
for kind, y0, y1, spans in [
 ('mummy',90,315,[(13,193),(195,366),(367,547),(548,758),(759,965),(978,1240),(1241,1440)]),
 ('scarab',358,513,[(14,215),(216,441),(442,646),(647,889),(890,1227),(1228,1444)]),
 ('bird',520,758,[(12,249),(250,484),(485,720),(739,914),(915,1174),(1175,1441)]),
 ('golem',760,995,[(24,247),(248,482),(483,714),(715,958),(966,1156),(1175,1440)])]:
 CROPS.setdefault('1-6/enemies/enemies.png', []).extend(
  (f'{kind}_{i}',x0,y0,x1,y1) for i,(x0,x1) in enumerate(spans))

def remove_board(image, stage):
 """Key the panel hues while retaining neutral ink and saturated artwork."""
 pixels=image.load()
 for y in range(image.height):
  for x in range(image.width):
   r,g,b,a=pixels[x,y]
   if stage == '1-7':
    matte = r < 45 and g < 76 and b < 105 and 8 <= g-r <= 35 and 8 <= b-g <= 35
   else:
    matte = r < 91 and g < 72 and b < 101 and 8 <= r-g <= 35 and 3 <= b-g <= 29 and abs(r-b) < 23
   if matte:pixels[x,y]=(r,g,b,0)
 # Close only tiny keying pinholes; fill enclosed regions so ink inside a
 # beetle or the dark facets inside a bank cannot become transparent.
 alpha=image.getchannel('A').filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.MinFilter(3))
 flood=Image.new('L',(image.width+2,image.height+2),0);flood.paste(alpha,(1,1))
 ImageDraw.floodfill(flood,(0,0),128,thresh=0)
 fp=flood.load();ap=alpha.load()
 for y in range(image.height):
  for x in range(image.width):
   if fp[x+1,y+1]==0:ap[x,y]=255
 image.putalpha(alpha)
 return image

with ZipFile(sys.argv[1]) as archive:
 for stage in ('1-6','1-7','1-8'):
  path = ROOT/'assets'/'split'/stage/'background'/'background.png'
  path.parent.mkdir(parents=True,exist_ok=True)
  with archive.open(PREFIX+stage+'/background/background_preview.png') as file:
   image=Image.open(file).convert('RGBA')
  if stage == '1-6':
   image=image.crop((0,0,image.width,745))
  else:
   # Distant clock window/cavern paintings, without the demo platforms/labels.
   with archive.open(PREFIX+stage+'/background/background_assets.png') as file:
    distant=Image.open(file).convert('RGBA')
   box=(498,23,706,193) if stage=='1-7' else (1249,26,1396,141)
   image=distant.crop(box)
  if stage != '1-6':
   image=image.resize((image.width*6,image.height*6),Image.Resampling.LANCZOS)
  image.save(path)
 for source,crops in CROPS.items():
  stage,category,_=source.split('/')
  with archive.open(PREFIX+source) as file:
   board=Image.open(file).convert('RGBA')
  for name,*box in crops:
   image=board.crop(box)
   original=image.copy()
   if stage != '1-6': image=remove_board(image,stage)
   if stage=='1-8' and name in ('ground','platform'):
    mask=Image.new('L',image.size,0)
    poly=([(0,4),(136,0),(136,28),(113,48),(98,78),(79,92),(57,82),(31,69),(10,42)]
          if name=='ground' else [(0,5),(129,0),(129,23),(113,38),(86,64),(65,70),(39,50),(17,31)])
    ImageDraw.Draw(mask).polygon(poly,fill=255)
    original.putalpha(mask);image=original
   if stage=='1-8' and category=='background' and name=='crystal':
    mask=Image.new('L',image.size,0)
    ImageDraw.Draw(mask).polygon([(32,1),(49,10),(53,34),(65,32),(73,57),(59,66),(14,66),(3,44),(12,37),(20,45),(23,14)],fill=255)
    image.putalpha(mask)
   bounds=image.getbbox()
   if not bounds: raise ValueError(name)
   image=image.crop(bounds)
   if stage=='1-8' and name in ('ground','platform'):
    image=image.crop((0,5,image.width,image.height))
   if stage!='1-6':
    image=image.resize((image.width*3,image.height*3),Image.Resampling.LANCZOS)
   target=ROOT/'assets'/'split'/stage/category/(name+'.png')
   target.parent.mkdir(parents=True,exist_ok=True)
   image.save(target)
 for stage in ('1-6','1-7','1-8'):
  files=sorted((ROOT/'assets'/'split'/stage).rglob('*.png'))
  sheet=Image.new('RGB',(1200,((len(files)+7)//8)*155),'#666a72')
  draw=ImageDraw.Draw(sheet)
  for i,file in enumerate(files):
   image=Image.open(file).convert('RGBA');image.thumbnail((140,120))
   x=(i%8)*150;y=(i//8)*155
   sheet.paste(image,(x+(140-image.width)//2,y+20),image)
   draw.text((x+3,y+3),file.stem,fill='white')
  target=ROOT/'build'/'asset-review'/(stage+'-cutouts.jpg')
  target.parent.mkdir(parents=True,exist_ok=True);sheet.save(target)
  print(stage,len(files),'runtime images')
