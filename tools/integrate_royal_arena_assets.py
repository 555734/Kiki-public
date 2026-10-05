"""Import the owner-supplied royal arena PNGs, removing adjacent sheet fragments."""
from pathlib import Path
from zipfile import ZipFile
import sys
from PIL import Image, ImageChops, ImageFilter
ROOT = Path(__file__).resolve().parents[1]
def actor(image):
    alpha=image.getchannel('A'); pixels=alpha.load(); seen=set(); groups=[]
    for y in range(image.height):
        for x in range(image.width):
            if pixels[x,y]<100 or (x,y) in seen: continue
            stack=[(x,y)];seen.add((x,y));group=[]
            while stack:
                point=stack.pop();group.append(point)
                for xx,yy in ((point[0]-1,point[1]),(point[0]+1,point[1]),(point[0],point[1]-1),(point[0],point[1]+1)):
                    if 0<=xx<image.width and 0<=yy<image.height and (xx,yy) not in seen and pixels[xx,yy]>=100:
                        seen.add((xx,yy));stack.append((xx,yy))
            groups.append(group)
    mask=Image.new('L',image.size,0);mp=mask.load()
    for point in max(groups,key=len):mp[point]=255
    image.putalpha(ImageChops.multiply(alpha,mask.filter(ImageFilter.MaxFilter(3))))
    return image.crop(image.getbbox())
with ZipFile(sys.argv[1]) as archive:
    count=0
    for name in archive.namelist():
        if not name.endswith('.png'):continue
        relative=Path(name).relative_to('Kiki_versus_royal_arena_assets')
        with archive.open(name) as file:image=Image.open(file).convert('RGBA')
        if relative.parts[0]!='background':image=actor(image)
        target=ROOT/'assets'/'versus'/'royal'/relative
        target.parent.mkdir(parents=True,exist_ok=True);image.save(target);count+=1
    print(count,'royal arena textures')
