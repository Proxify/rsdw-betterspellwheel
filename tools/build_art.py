#!/usr/bin/env python3
"""Deterministic UMG wheel geometry; no game assets are distributed.

White/gold procedural annular sectors share the model's radii. Supersampling
keeps the radial silhouette smooth at 1080p and scaled high-DPI resolutions.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter
from math import sin, cos, radians
OUT = Path(__file__).resolve().parents[1] / 'Assets'
S = 3
GOLD = (208, 177, 108)
def point(a,r,c): return ((c+sin(radians(a))*r)*S,(c-cos(radians(a))*r)*S)
def poly(a,b,ri,ro,c):
    steps=max(12,int((b-a)*3))
    return [point(a+(b-a)*i/steps,ro,c) for i in range(steps+1)]+[point(b-(b-a)*i/steps,ri,c) for i in range(steps+1)]
def sector(name,ri,ro,angle,active):
    side=848; c=side/2
    im=Image.new('RGBA',(side*S,side*S))
    d=ImageDraw.Draw(im)
    a,b=-angle/2+0.7,angle/2-0.7
    for r in range(ri,ro):
        t=(r-ri)/(ro-ri)
        glow=sin(t*3.14159)
        rgb=(int(26+24*glow),int(25+17*glow),int(20+7*glow)) if active else (15+int(glow*8),19+int(glow*6),20+int(glow*3))
        d.polygon(poly(a,b,r,r+1.3,c),fill=(*rgb,245 if active else 228))
    edge=(*GOLD,240) if active else (154,135,90,120)
    d.line(poly(a,b,ri,ro,c)+[point(a,ro,c)],fill=edge,width=(2 if active else 1)*S,joint='curve')
    for radius in [ri+5,ro-5]:
        pts=[point(a+0.7+(b-a-1.4)*i/60,radius,c) for i in range(61)]
        d.line(pts,fill=(*GOLD,90 if active else 35),width=S)
    mid=(a+b)/2
    if name.startswith('skill'):
        d.polygon([point(mid,ro-10,c),point(mid-0.9,ro-15,c),point(mid,ro-20,c),point(mid+0.9,ro-15,c)],fill=(*GOLD,210 if active else 90))
    if active:
        light=Image.new('RGBA',im.size); ld=ImageDraw.Draw(light)
        ld.line(poly(a,b,ri,ro,c)+[point(a,ro,c)],fill=(*GOLD,110),width=3*S,joint='curve')
        im=Image.alpha_composite(light.filter(ImageFilter.GaussianBlur(5*S)),im)
    im.resize((side,side),Image.Resampling.LANCZOS).save(OUT/(name+'.png'))
OUT.mkdir(exist_ok=True)
for name,ri,ro,a in [('skill',132,264,30),('spell',282,408,20)]:
    sector(name,ri,ro,a,False); sector(name+'_active',ri,ro,a,True)
side=848; c=side/2
im=Image.new('RGBA',(side*S,side*S)); d=ImageDraw.Draw(im)
for r in range(122,0,-1):
    t=r/122
    d.ellipse(((c-r)*S,(c-r)*S,(c+r)*S,(c+r)*S),fill=(12+int(7*t),17+int(7*t),19+int(5*t),245))
for r,alpha in [(124,165),(119,75),(112,40)]:
    d.ellipse(((c-r)*S,(c-r)*S,(c+r)*S,(c+r)*S),outline=(*GOLD,alpha),width=S)
for a in range(0,360,30):
    d.line([point(a,125,c),point(a,128,c)],fill=(*GOLD,145),width=S)
im.resize((side,side),Image.Resampling.LANCZOS).save(OUT/'center.png')
print('Built five wheel textures')
