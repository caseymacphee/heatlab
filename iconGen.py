from PIL import Image, ImageDraw, ImageFilter
import numpy as np, os

out_dir="./icons"
OUT=1024

def cubic(p0,p1,p2,p3,t):
    return (
        (1-t)**3*p0[0] + 3*(1-t)**2*t*p1[0] + 3*(1-t)*t**2*p2[0] + t**3*p3[0],
        (1-t)**3*p0[1] + 3*(1-t)**2*t*p1[1] + 3*(1-t)*t**2*p2[1] + t**3*p3[1],
    )

def make_arc_mask(out_size=1024, scale=10, stroke_w=54):
    W=H=out_size*scale
    mask=Image.new("L",(W,H),0)
    d=ImageDraw.Draw(mask)

    # Higher amplitude + end slightly higher than start:
    # Start y=560, end y=535, peak pulled upward via control point.
    p0 = (160 * scale, 560 * scale)
    p1 = (360 * scale, 560 * scale)
    p2 = (664 * scale, 250 * scale)
    p3 = (864 * scale, 535 * scale)

    pts=[cubic(p0,p1,p2,p3,i/1999) for i in range(2000)]
    d.line(pts, fill=255, width=stroke_w*scale, joint="curve")

    cap_r=(stroke_w*scale)/2
    for x,y in (pts[0], pts[-1]):
        d.ellipse((x-cap_r, y-cap_r, x+cap_r, y+cap_r), fill=255)

    return mask.resize((out_size,out_size), resample=Image.Resampling.LANCZOS)

def clean_mask(mask_small: Image.Image):
    m = mask_small.filter(ImageFilter.MaxFilter(size=5)).filter(ImageFilter.MinFilter(size=5))
    a = np.array(m, dtype=np.uint8)
    a[a < 8] = 0
    a[a >= 200] = 255

    m2 = Image.fromarray(a).filter(ImageFilter.MaxFilter(size=3)).filter(ImageFilter.MinFilter(size=3))
    a2 = np.array(m2, dtype=np.uint8)
    a2[a2 >= 200] = 255
    a2[a2 < 8] = 0
    return Image.fromarray(a2, mode="L")

def make_foreground_png_solid(path, stroke_w=60):
    mask = make_arc_mask(out_size=OUT, scale=10, stroke_w=stroke_w)
    mask = clean_mask(mask)
    fg = Image.new("RGBA",(OUT,OUT),(255,255,255,255))
    fg.putalpha(mask)
    fg.save(path,"PNG")

arc_v5 = os.path.join(out_dir, "heat_pulse_arc_solid_foreground_1024_v5_highamp.png")
make_foreground_png_solid(arc_v5, stroke_w=75)

(arc_v5, os.path.getsize(arc_v5))
