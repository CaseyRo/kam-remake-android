import json,sys
M=json.load(open('/Users/caseyromkes/dev/kam_ipad/mods/friendly/_originals/manifest.json'))
S={s['id']:s for s in M['sprites'] if s['archive']=='GUI.rxx'}
L,MO,H,W,WN='var(--color-linen)','var(--color-moss-light)','var(--color-honey)','var(--color-woad)','var(--color-walnut)'
INK='#3A2A1C'
def p(d,fill='none',sw=1.0,st=INK): return ('p',d,fill,sw,st)
def c(cx,cy,r,fill,sw=1.0,st=INK): return ('c',cx,cy,r,fill,sw,st)
def r(x,y,w,h,fill,rx=0,sw=1.0,st=INK): return ('r',x,y,w,h,fill,rx,sw,st)
def e(cx,cy,rx,ry,fill,sw=1.0): return ('e',cx,cy,rx,ry,fill,sw)
MINE=lambda ore,ost=INK,osw=1.0:[p('M3.5 20.5v-7a8.5 8.5 0 0 1 17 0v7z','#1E2633'),p('M10 20.5l2-5.5 4.5-1.5 3.5 3.5-1 3.5z',ore,osw,ost)]
I={
301:('Sawmill',H,[r(3,13,18,4,'none',1),r(5,8,14,4,'none',1),p('M4 21h16'),p('M12 3v2.5')]),
302:('Iron smithy',H,[p('M3.5 8h13c0 3-2 4.5-5 4.5V15h3v4h-9v-4h3v-2.5c-3 0-5-1.5-5-4.5z','#9AA6B4'),p('M16.5 8h4l-4 3')]),
303:('Weapon smithy',W,[p('M19.5 4.5l-.5 3.5-10 10-3-3 10-10z','#E6DCC6'),p('M5 13l6 6M4 20l3-3')]),
304:('Coal mine',H,MINE('#3B3F46','#E6DCC6',0.8)),
305:('Iron mine',H,MINE('#A9B4C2')),
306:('Gold mine',H,MINE('#F6D27A')),
307:('Fisher hut',MO,[p('M2.5 12c3-4 8-5.5 12-3l4.5-3v12l-4.5-3c-4 2.5-9 1-12-3z','#8FA9CC'),c(8,11,0.6,'#1E2633')]),
308:('Bakery',MO,[p('M3.5 16c0-4.5 4-8 8.5-8s8.5 3.5 8.5 8v2h-17z','#E2B851'),p('M9 10.5l-1 3M13 10l-1 3.5M17 11.5l-1 3')]),
309:('Farm',MO,[p('M12 21V6'),p('M12 6c0-2 .5-3 0-4-.5 1-1 2 0 4','#E2B851'),p('M12 11c-2.5-.5-4-2-4-4.5 2.5.5 4 2 4 4.5zM12 11c2.5-.5 4-2 4-4.5-2.5.5-4 2-4 4.5zM12 16c-2.5-.5-4-2-4-4.5 2.5.5 4 2 4 4.5zM12 16c2.5-.5 4-2 4-4.5-2.5.5-4 2-4 4.5z','#E2B851')]),
310:('Woodcutter',H,[p('M4.5 20L15 9.5'),p('M12.5 4.5c3.5-.5 7 2.5 7 6.5l-4.5.5-3.5-3.5z','#E6DCC6')]),
311:('Armor smithy',W,[p('M4.5 14a7.5 7.5 0 0 1 15 0v6h-5v-4.5h-5V20h-5z','#E6DCC6'),p('M12 6.5V14M8 12h8',sw=0.8)]),
312:('Store',L,[p('M4 7l8-4 8 4v10l-8 4-8-4z','#D4A040'),p('M4 7l8 4 8-4M12 11v10')]),
313:('Stables',W,[p('M6.5 4v7.5a5.5 5.5 0 0 0 11 0V4',sw=1.3),p('M6.5 7h.01M17.5 7h.01M7.5 13h.01M16.5 13h.01',sw=0.8,st='#F2ECDF')]),
314:('School',L,[p('M3 6c3-1 6-1 9 1v12c-3-2-6-2-9-1z'),p('M21 6c-3-1-6-1-9 1v12c3-2 6-2 9-1z')]),
315:('Quarry',H,[p('M3 20h18'),r(4,13,7,7,'#E6DCC6'),r(13,11,7,9,'#E6DCC6'),r(7.5,6,7,7,'#E6DCC6')]),
316:('Metallurgist',H,[p('M3.5 19l3-6h11l3 6z','#F6D27A'),p('M12 3c2.5 2.5 2.5 5 0 6.5-2.5-1.5-2.5-4 0-6.5z','#A64B3C')]),
317:('Swine',MO,[p('M6 8.5L4.5 4.5l4 2M18 8.5l1.5-4-4 2'),e(12,13,7.5,6.5,'#E8B4A6'),e(12,15.5,2.6,1.8,'none'),p('M9 11v.5M15 11v.5')]),
318:('Watch tower',W,[p('M7 21V9.5h10V21z','#E6DCC6'),p('M5.5 9.5V4.5h2.5v2h2v-2h4v2h2v-2h2.5v5z','#E6DCC6'),p('M10.5 21v-4a1.5 1.5 0 0 1 3 0v4')]),
319:('Town hall',L,[p('M12 3v2.5'),p('M6 16.5c1.2-1.2 1.2-3.5 1.2-6.5a4.8 4.8 0 0 1 9.6 0c0 3 0 5.3 1.2 6.5z','#F0BE4E'),p('M4.5 16.5h15'),c(12,19.5,1.6,'#B07A3E')]),
320:('Weapon workshop',W,[p('M7 3c7 3 7 15 0 18'),p('M7 3v18',sw=0.6),p('M4 12h15M16.5 9.5L19 12l-2.5 2.5')]),
321:('Armor workshop',W,[p('M12 3l7.5 3v6c0 5-3.5 8-7.5 9-4-1-7.5-4-7.5-9V6z','#B7834A'),p('M12 3v18M4.5 11h15',sw=0.7)]),
322:('Barracks',W,[p('M5 21V3'),p('M5 4h13l-3 4 3 4H5z','#A64B3C')]),
323:('Mill',MO,[p('M10 21l.8-8h2.4l.8 8z','#E6DCC6'),p('M12 11L5 4M12 11l7-7M12 11l-6 6M12 11l6 6'),c(12,11,1.6,'#1E2633')]),
324:('Siege workshop',W,[p('M3.5 15.5h17'),p('M8 15.5L17.5 5.5'),c(18.5,4.8,2.3,'#E6DCC6'),c(7,18,2.6,'#B07A3E'),c(17,18,2.6,'#B07A3E')]),
325:('Butchers',MO,[p('M15 3.5c3.5 0 5.5 3 5.5 6s-3 6-7 6l-4 4'),p('M15 3.5c3.5 0 5.5 3 5.5 6s-3 6-7 6c-1.5-1-2.5-2.5-2-5 .5-4 1-7 3.5-7z','#C9705E'),p('M9.5 19.5l-2.5-2.5M6 21a1.5 1.5 0 1 1-2-2')]),
326:('Tannery',H,[p('M7 3.5h10l2 4-2 3.5 2 4-2 5.5H7l-2-5.5 2-4-2-3.5z','#B7834A')]),
327:('Marketplace',L,[p('M12 3.5V20M8 20.5h8M4.5 6.5h15'),p('M4.5 6.5l-2.3 6.5M4.5 6.5l2.3 6.5M19.5 6.5l-2.3 6.5M19.5 6.5l2.3 6.5',sw=0.7),p('M2 13h5a2.5 2.5 0 0 1-5 0zM17 13h5a2.5 2.5 0 0 1-5 0z','#F0BE4E')]),
328:('Inn',MO,[p('M5 8h10v10a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2z','#F2ECDF'),p('M15 10.5h2a2 2 0 0 1 2 2v1.5a2 2 0 0 1-2 2h-2'),p('M5 5c2-1.5 4 .5 6-.5s3-.5 4 0')]),
329:('Vineyard',MO,[p('M4 21h16M7 21V9M17 21V9M7 9h10'),c(12,13,2,'#6B4A7A'),c(12,17,2,'#6B4A7A'),p('M5 6c1-2 3-3 5-2M19 6c-1-2-3-3-5-2')]),
335:('Road',L,[p('M7 21L10 3M17 21L14 3'),p('M12 6v2M12 11v2M12 16v2')]),
336:('Wine field',MO,[p('M12 7c0-2 1-3.5 3-4'),c(9.5,10,2.4,'#6B4A7A'),c(14.5,10,2.4,'#6B4A7A'),c(12,14,2.4,'#6B4A7A'),c(12,18.5,2.2,'#6B4A7A')]),
337:('Field',MO,[p('M3 9l9-5 9 5-9 5z'),p('M7.5 6.5l9 5M10.5 5l9 5M4.5 8l9 5',sw=0.7),p('M3 9v6l9 5 9-5V9')]),
340:('Erase',W,[p('M6 6l12 12M18 6L6 18',sw=1.3,st='#FFF6DF')]),
# 41 is also the generic "unknown" icon (unknown ware, school in progress, stats, map-editor tab): a question mark, not a padlock
41:('Unknown',WN,[p('M8 8a4 4 0 1 1 5.6 3.7c-1 .45-1.6 1.2-1.6 2.3v1',st='#E6D2A6'),p('M12 20h.01',sw=1.3,st='#E6D2A6')]),
}
I[340]=('Erase','var(--color-madder)',I[340][2])
def svg(items,s,base,vb='0 0 24 24',sh=None):
    o=[]
    for it in items:
        k=it[0]
        if k=='p': _,d,f,sw,st=it; o.append(f'<path d="{d}" fill="{f}" stroke="{st}" stroke-width="{base*sw:.2f}" stroke-linecap="round" stroke-linejoin="round"/>')
        if k=='c': _,cx,cy,rr,f,sw,st=it; o.append(f'<circle cx="{cx}" cy="{cy}" r="{rr}" fill="{f}" stroke="{st}" stroke-width="{base*sw:.2f}"/>')
        if k=='r': _,x,y,w,h,f,rx,sw,st=it; o.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" fill="{f}" stroke="{st}" stroke-width="{base*sw:.2f}" stroke-linejoin="round"/>')
        if k=='e': _,cx,cy,rx,ry,f,sw=it; o.append(f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" fill="{f}" stroke="{INK}" stroke-width="{base*sw:.2f}"/>')
    return f'<svg width="{s}" height="{sh or s}" viewBox="{vb}" xmlns="http://www.w3.org/2000/svg" style="flex-shrink:0">'+''.join(o)+'</svg>'
out={}
for i,(name,plate,items) in I.items():
    if i==41: w,h=S[i]['width'],S[i]['height']  # 41 keeps its 14x18: it also sits in non-build slots
    else: w=h=30  # uniform build plates, as in Paper "10 Final" F5; the engine centres GUI pictures in the 33x33 button by pixel size, pivots unused
    m=min(w,h)
    s=21 if m>=30 else max(11,round(m*0.72)); rad=6 if m>=24 else 5 if m>=19 else 4 if m>=16 else 3
    base=max(2.0, 1.6*24/s)  # 2 in viewBox at 21px; keep >=1.6 real px on small sprites
    g=svg(items,9,2.5,'5 1.5 14 21.5',14) if i==41 else svg(items,s,base)  # 41: viewBox cropped to the "?" so it fills the 18 px plate; 2.5 units = 1.6 px
    out[i]=dict(name=name,w=w,h=h,html=f'<div layer-name="plate" style="width:{w}px;height:{h}px;border-radius:{rad}px;background-color:{plate};display:flex;align-items:center;justify-content:center;flex-shrink:0">'+g+'</div>')
json.dump(out,open(sys.argv[1],'w'),indent=0)
print(len(out))
