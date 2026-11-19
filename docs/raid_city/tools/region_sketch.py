# Top-down region sketch for docs/raid_city (not game code). 1 px = 5 m. Region 4.0 km x 6.0 km, north up.
from PIL import Image, ImageDraw, ImageFont
import os
S = 0.2  # px per metre
W, H = int(4000*S), int(6000*S)
PAD_T, PAD_B = 70, 150
img = Image.new("RGB", (W, H+PAD_T+PAD_B), "#1b2430")
d = ImageDraw.Draw(img)
F = "/usr/share/fonts/truetype/dejavu/"
def font(n, s):
    for c in [n, "DejaVuSans.ttf", "DejaVuSansMono.ttf"]:
        if os.path.exists(F+c): return ImageFont.truetype(F+c, s)
    return ImageFont.load_default()
f_t, f_b, f_s = font("DejaVuSans-Bold.ttf", 19), font("DejaVuSans-Bold.ttf", 15), font("DejaVuSans.ttf", 12)
def P(x, y): return (x*S, PAD_T + y*S)          # metres from NW corner
def R(x0, y0, x1, y1, **k): d.rectangle([P(x0,y0), P(x1,y1)], **k)
def poly(pts, **k): d.polygon([P(*p) for p in pts], **k)
def line(pts, w, c): d.line([P(*p) for p in pts], fill=c, width=w, joint="curve")
def text(x, y, s, f=f_s, c="#f2f2f2", anchor="mm"): d.text(P(x,y), s, font=f, fill=c, anchor=anchor)
# land
R(0, 0, 4000, 6000, fill="#5b6b3c")
poly([(0,0),(4000,0),(4000,1500),(0,1300)], fill="#a08a5c")            # dry north (small town)
poly([(0,4300),(300,4250),(500,4500),(400,6000),(0,6000)], fill="#2c4f6e")  # sea west
poly([(3600,4200),(4000,4100),(4000,6000),(3500,6000)], fill="#2c4f6e")      # sea east
R(0, 5800, 4000, 6000, fill="#2c4f6e")                                     # sea south
# forest belts
poly([(2600,1700),(4000,1500),(4000,3700),(2900,3500)], fill="#3e5a2c")
poly([(0,1900),(900,1800),(1000,3000),(0,3200)], fill="#4a6532")
# farms
for i in range(4):
    for j in range(3): R(150+i*170, 2000+j*170, 300+i*170, 2140+j*170, fill="#8c9a4a" if (i+j)%2 else "#a6a35a")
text(500, 2580, "FARMS")
# mountain + statue
poly([(1500,1700),(2050,1350),(2500,1800),(2300,2350),(1700,2300)], fill="#6f6a63")
poly([(1900,1600),(2050,1450),(2200,1650),(2050,1750)], fill="#c9c4bb")
d.ellipse([P(2020,1520), P(2080,1580)], fill="#e6c34a"); text(2050, 1840, "MOUNTAIN + STATUE", f_b)
text(2050, 1890, "landmark, seen from both towns")
# waterfall forest + lake
d.ellipse([P(3150,2050), P(3600,2400)], fill="#2c4f6e"); line([(3500,1800),(3420,2080)], 6, "#9fd3ff")
text(3380, 2470, "WATERFALL FOREST", f_b); text(3380, 2520, "cave stash behind falls")
# resource sites
for x,y,n in [(1200,2300,"QUARRY"),(900,3050,"MINE"),(400,3500,"LOGGING"),(2900,2900,"SALVAGE YARD"),(3300,3300,"OUTPOST"),(2600,3900,"CRASHED SHIP")]:
    d.ellipse([P(x-90,y-60), P(x+90,y+60)], outline="#e0b060", width=2); text(x, y, n, f_s, "#ffe2a8")
# highway + dirt roads
line([(2000,1100),(2000,1500),(1700,2500),(1950,3300),(2000,4200)], 7, "#d8d8d8")
line([(2000,1100),(2000,1500),(1700,2500),(1950,3300),(2000,4200)], 1, "#333333")
for pts in [[(1700,2500),(1200,2300)],[(1800,2900),(900,3050),(400,3500)],[(1950,3300),(2900,2900),(3300,3300)],[(1800,2700),(2600,2150),(3380,2250)],[(1600,2200),(600,2300)],[(1990,3800),(2600,3900)]]:
    line(pts, 3, "#b39a6a")
text(1780, 3150, "HIGHWAY (vehicle showcase)", f_s, "#ffffff", "rm")
# small town (north)
R(1650, 350, 2400, 1000, fill="#b89f73", outline="#3b2f1f", width=2)
for i in range(6):
    for j in range(5): R(1700+i*115, 400+j*115, 1780+i*115, 470+j*115, fill="#8a6f4c")
text(2025, 300, "SMALL TOWN (north)", f_b); text(2025, 1040, "corner store · ATMs · small bank · sheriff · motel")
# city (south)
R(500, 4250, 3550, 5800, fill="#3b3f47", outline="#111111", width=2)
line([(2050,4200),(1950,4700),(2150,5200),(2000,5850)], 22, "#2c4f6e")   # river
for (y, n) in [(4520,"B1"),(4980,"B2"),(5450,"B3")]:
    line([(1750,y),(2350,y)], 6, "#d8d8d8")
R(700, 4350, 1750, 4900, fill="#46506a"); text(1100, 4440, "DOWNTOWN", f_b); text(1100, 4500, "corporate tower")
d.rectangle([P(1420,4740), P(1640,4880)], fill="#d9c9a3", outline="#111"); text(1530, 4810, "BANK", f_s, "#111111")
R(700, 4950, 1750, 5350, fill="#5a3f6e"); text(1220, 5080, "NEON MARKET", f_b); text(1220, 5200, "grocery · ATMs · pawn shop")
R(700, 5400, 1750, 5750, fill="#59544a"); text(1220, 5575, "INDUSTRIAL DOCKS", f_b)
R(2350, 4350, 3450, 5000, fill="#4d6a44"); text(2900, 4675, "SUBURBS", f_b)
R(2350, 5050, 3450, 5750, fill="#555c62"); text(2900, 5300, "POLICE HQ · HOSPITAL", f_b); text(2900, 5340, "garage · delivery depot")
d.ellipse([P(2400,4380), P(2800,4620)], fill="#3f7a3a"); text(2600, 4500, "CITY PARK")
R(720, 4700, 2330, 5330, outline="#ffd36b", width=4); text(800, 5290, "PHASE 1 slice (~0.6 x 0.5 km core)", f_s, "#ffd36b", "lm")
for (y, n) in [(4520,"B1"),(4980,"B2"),(5450,"B3")]: text(2050, y-55, n, f_b, "#ffd36b")
# extracts
def mark(x, y, c, t):
    d.ellipse([P(x-35,y-35), P(x+35,y+35)], fill=c, outline="#111", width=2); text(x+50, y, t, f_s, "#ffffff", "lm")
civ, crim, ship = "#3fb950", "#e5534b", "#58a6ff"
mark(2400, 900, ship, "ship pad (town)"); mark(450, 5650, ship, "ship pad (city)")
mark(2000, 3700, civ, "highway toll"); mark(3100, 5650, civ, "train station"); mark(3150, 3150, civ, "bus station")
mark(2200, 4150, crim, "tunnel"); mark(1350, 5780, crim, "dock smuggler"); mark(1250, 4620, crim, "rooftop pickup"); mark(2000, 650, crim, "fixer (town)")
# compass, scale, legend
text(3850, 120, "N ↑", f_b)
line([(150, 5950), (1150, 5950)], 4, "#ffffff"); text(650, 5915, "1 km", f_s)
d.text((12, 14), "Region sketch: city + region (4 km x 6 km), not to final scale", font=f_t, fill="#ffffff")
ly = PAD_T + H + 18
for i, (c, t) in enumerate([(ship, "Ship drop zone / ship-pad civilian extract"), (civ, "Civilian extract (unflagged only)"), (crim, "Criminal extract (paid, keyed or intel)"), ("#ffd36b", "Bridge chokepoint (police block at heat 3+)"), ("#e0b060", "Resource node (wild-raid style)")]):
    y = ly + i*24; d.rectangle([14, y, 34, y+16], fill=c); d.text((44, y), t, font=f_s, fill="#ffffff")
d.text((W-14, ly), "Source: docs/raid_city/02_world_layout.md\nGenerated by a throwaway PIL script;\nlayout follows mockups/region_map.jpg", font=f_s, fill="#c0c0c0", anchor="ra")
img.save(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "region_sketch.png"), optimize=True)
print(img.size)
