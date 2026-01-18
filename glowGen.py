from PIL import Image, ImageFilter
import numpy as np, os

out_dir = "/mnt/data"
OUT = 1024


def make_glow_png(path, center=(512, 410), radius=280, alpha0=185, blur=20, power=1.9):
    yy, xx = np.mgrid[0:OUT, 0:OUT].astype(np.float32)
    cx, cy = center
    dist = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2)

    t = np.clip(1 - dist / float(radius), 0, 1)
    alpha = (t**power) * alpha0

    glow_rgba = np.zeros((OUT, OUT, 4), dtype=np.uint8)
    glow_rgba[..., :3] = 255
    glow_rgba[..., 3] = np.clip(alpha, 0, 255).astype(np.uint8)

    glow = Image.fromarray(glow_rgba, mode="RGBA").filter(
        ImageFilter.GaussianBlur(radius=blur)
    )
    glow.save(path, "PNG")


mid_glow = os.path.join(out_dir, "heat_pulse_arc_glow_only_1024_mid_v3.png")
make_glow_png(mid_glow)

(mid_glow, os.path.getsize(mid_glow))
