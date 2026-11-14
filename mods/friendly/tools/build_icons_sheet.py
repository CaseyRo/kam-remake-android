# Contact sheet: build page layout (KM_GUIGameBuild) at 1x on oak, new vs original, then x3 nearest.
from PIL import Image, ImageDraw
import sys
R='/Users/caseyromkes/dev/kam_ipad/mods/friendly/'
order=[314,328,315,310,301,309,323,308,317,325,329,306,304,316,320,326,321,313,305,302,303,311,322,312,318,307,327,319,324,41]
tools=[(0,335),(37,337),(74,336),(148,340)]
def panel(src):
    im=Image.new('RGBA',(181+16,120+6*37+33+16),(201,154,94,255))
    d=ImageDraw.Draw(im)
    def cell(x,y,i):
        x+=8;y+=8
        d.rectangle([x,y,x+32,y+32],fill=(130,100,61,255))
        sp=Image.open(src%i).convert('RGBA')
        im.alpha_composite(sp,(x+(33-sp.width)//2,y+(33-sp.height)//2))
    for x,i in tools: cell(x,0,i)
    for n,i in enumerate(order): cell((n%5)*37,40+(n//5)*37,i)
    return im
a=panel(R+'Modding graphics/4_%04d.png'); b=panel(R+'_originals/4_%04d.png')
s=Image.new('RGBA',(a.width*2+12,a.height),(60,40,25,255)); s.alpha_composite(b,(0,0)); s.alpha_composite(a,(a.width+12,0))
s.save(sys.argv[1]); s.resize((s.width*3,s.height*3),Image.NEAREST).save(sys.argv[2])
