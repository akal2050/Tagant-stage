"""Catalogue sheet of the three frame families, 9-sliced at real UI sizes with labels."""
import sys
from PIL import Image, ImageDraw, ImageFont
A = sys.argv[1]; OUT = sys.argv[2]
M = 40
def nine(img, w, h, m=M, scale=0.8):
    # scale texture margins by `scale`
    src = img.resize((int(img.width*scale), int(img.height*scale)), Image.LANCZOS); m=int(m*scale)
    W, H = src.size; out = Image.new("RGBA", (w, h), (0,0,0,0))
    xs=[(0,m,0,m),(m,W-m,m,w-m),(W-m,W,w-m,w)]; ys=[(0,m,0,m),(m,H-m,m,h-m),(H-m,H,h-m,h)]
    for (sx0,sx1,dx0,dx1) in xs:
        for (sy0,sy1,dy0,dy1) in ys:
            if dx1>dx0 and dy1>dy0:
                out.paste(src.crop((sx0,sy0,sx1,sy1)).resize((dx1-dx0,dy1-dy0),Image.LANCZOS),(dx0,dy0))
    return out
bg = Image.new("RGBA",(1800,1060),(0,0,0,255))
# warm ground gradient like the stage
g=ImageDraw.Draw(bg)
for y in range(1060):
    t=y/1060; g.line([(0,y),(1800,y)],fill=(int(40+70*t),int(22+28*t),int(16+14*t),255))
tek=ImageFont.truetype(A+"/fonts/Tektur.ttf",26); tek_s=ImageFont.truetype(A+"/fonts/Tektur.ttf",20)
meg=ImageFont.truetype(A+"/fonts/Megrim.ttf",44); hj=ImageFont.truetype(A+"/fonts/Handjet.ttf",30)
SALT=(244,241,232,255); RED=(225,60,35,255)
g.text((60,30),"TAGANT  KARAOKE  -  INTERFACE FRAMES",font=meg,fill=SALT)
names={"heptagram":"A  HEPTAGRAM SIGIL","arabesque":"B  ARABESQUE SCROLL","signal":"C  SIGNAL INSTRUMENT"}
for i,st in enumerate(["heptagram","arabesque","signal"]):
    x0=60+i*580; y0=130
    g.text((x0,y0),names[st],font=tek,fill=RED)
    pan=Image.open(f"{A}/ui_frames/{st}/panel.png"); bt=Image.open(f"{A}/ui_frames/{st}/button.png")
    bh=Image.open(f"{A}/ui_frames/{st}/button_hover.png"); bp=Image.open(f"{A}/ui_frames/{st}/button_pressed.png")
    p=nine(pan,520,330); bg.alpha_composite(p,(x0,y0+50))
    for k,(t,img) in enumerate([("LISTEN",bp),("SING",bt),("REHEARSE",bh),("DIALOGUE",bt)]):
        b=nine(img,220,72); bx=x0+30+(k%2)*240; by=y0+80+(k//2)*100
        bg.alpha_composite(b,(bx,by)); g.text((bx+110,by+36),t,font=tek_s,fill=SALT,anchor="mm")
    g.text((x0+30,y0+290),"song: Dove of the salt circle",font=tek_s,fill=SALT)
    # arabic button + slot list
    b=nine(bt,240,72); bg.alpha_composite(b,(x0+250,y0+410)); g.text((x0+370,y0+446),"عربي",font=hj,fill=SALT,anchor="mm")
    for k in range(5):
        img = bp if k==2 else bt
        b=nine(img,220,64); bg.alpha_composite(b,(x0,y0+400+k*76))
        g.text((x0+20,y0+432+k*76),["1  DOVE","2  JACKAL","3  GOAT","4  HYENA","5  MYNA"][k],font=tek_s,fill=SALT,anchor="lm")
    # arrows
    for k,ch in enumerate(["<",">"]):
        b=nine(bt,90,90); bg.alpha_composite(b,(x0+260+k*110,y0+500)); g.text((x0+305+k*110,y0+545),ch,font=meg,fill=SALT,anchor="mm")
    g.text((x0+250,y0+610),"normal / hover / pressed",font=tek_s,fill=(244,241,232,150))
bg.convert("RGB").save(OUT)
