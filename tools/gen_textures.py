"""Genereert alle PS1-achtige textures (64x64 pixels) voor de game.

Gebruik:  python tools/gen_textures.py
Vereist:  pip install numpy pillow

Alle textures zijn expres klein en een beetje vies, zoals op de PlayStation 1.
"""
import os
import numpy as np
from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "textures")
S = 64
rng = np.random.default_rng(1337)


def noise(scale=1.0, size=S):
    return rng.normal(0.0, scale, (size, size))


def smooth_noise(cells, amp=1.0, size=S):
    """Wazige 'wolken'-ruis die naadloos tegelt."""
    base = rng.normal(0.0, 1.0, (cells, cells))
    img = Image.fromarray(((base - base.min()) / (np.ptp(base) + 1e-9) * 255).astype(np.uint8))
    # 3x3 tegelen en het midden pakken zodat de randen naadloos zijn
    tiled = Image.new("L", (cells * 3, cells * 3))
    for i in range(3):
        for j in range(3):
            tiled.paste(img, (i * cells, j * cells))
    big = tiled.resize((size * 3, size * 3), Image.BICUBIC)
    arr = np.asarray(big, dtype=np.float32)[size:size * 2, size:size * 2] / 255.0
    return (arr - 0.5) * 2.0 * amp


def save(name, rgb):
    rgb = np.clip(rgb, 0, 255).astype(np.uint8)
    Image.fromarray(rgb, "RGB").save(os.path.join(OUT, name + ".png"))
    print("  ", name)


def colorize(value, color):
    """value: 2D array rond 1.0, color: (r,g,b)"""
    return np.stack([value * c for c in color], axis=-1)


def wood_floor():
    y, x = np.mgrid[0:S, 0:S]
    plank_h = 16
    row = y // plank_h
    offset = (row * 23) % S
    xs = (x + offset) % S
    plank_id = row * 4 + xs // 32
    tone = 1.0 + (np.sin(plank_id * 12.9898) * 0.5) * 0.18
    grain = np.sin((y % plank_h) * 1.3 + smooth_noise(4, 3.0)) * 0.06
    v = tone + grain + noise(0.04) + smooth_noise(8, 0.08)
    v[(y % plank_h) == 0] *= 0.45
    v[(xs % 32) == 0] *= 0.55
    save("wood_floor", colorize(v, (122, 84, 52)))


def carpet():
    v = 1.0 + noise(0.12) + smooth_noise(6, 0.1)
    save("carpet", colorize(v, (78, 84, 104)))


def tile(name, color, grout, n=4):
    y, x = np.mgrid[0:S, 0:S]
    size = S // n
    v = 1.0 + noise(0.03) + smooth_noise(4, 0.06)
    rgb = colorize(v, color)
    g = ((x % size) < 1) | ((y % size) < 1)
    rgb[g] = np.array(grout) * (1.0 + noise(0.1)[g, None])
    save(name, rgb)


def checker_floor():
    y, x = np.mgrid[0:S, 0:S]
    c = ((x // 16) + (y // 16)) % 2
    v = 1.0 + noise(0.04) + smooth_noise(4, 0.07)
    a = colorize(v, (196, 190, 170))
    b = colorize(v, (70, 66, 60))
    rgb = np.where(c[..., None] == 0, a, b)
    save("kitchen_floor", rgb)


def wallpaper():
    y, x = np.mgrid[0:S, 0:S]
    stripes = np.where((x % 16) < 8, 1.0, 0.94)
    dots = np.where(((x % 16) == 12) & ((y % 16) == 4), 0.85, 1.0)
    stains = np.clip(smooth_noise(3, 1.0), 0.3, 1.0) - 0.3
    v = stripes * dots - stains * 0.12 + noise(0.025)
    save("wallpaper", colorize(v, (196, 180, 150)))


def wall_plain():
    v = 1.0 + noise(0.03) + smooth_noise(5, 0.05)
    save("wall_plain", colorize(v, (178, 176, 168)))


def wall_bedroom():
    y, x = np.mgrid[0:S, 0:S]
    v = 1.0 + noise(0.03) + smooth_noise(5, 0.05)
    v = v * np.where((x % 32) < 2, 0.93, 1.0)
    save("wall_bedroom", colorize(v, (112, 136, 150)))


def ceiling():
    v = 1.0 + noise(0.07) + smooth_noise(8, 0.04)
    save("ceiling", colorize(v, (190, 188, 182)))


def wood_furniture(name, color):
    y, x = np.mgrid[0:S, 0:S]
    grain = np.sin(x * 0.9 + smooth_noise(3, 4.0) * 2.0) * 0.07
    v = 1.0 + grain + noise(0.03) + smooth_noise(6, 0.05)
    save(name, colorize(v, color))


def fabric(name, color, amp=0.1):
    y, x = np.mgrid[0:S, 0:S]
    weave = np.where(((x + y) % 2) == 0, 1.03, 0.97)
    v = weave + noise(amp * 0.5) + smooth_noise(6, amp)
    save(name, colorize(v, color))


def blanket():
    y, x = np.mgrid[0:S, 0:S]
    base = np.array([60, 72, 120], dtype=np.float32)
    rgb = np.ones((S, S, 3)) * base
    band_x = (x % 16) < 4
    band_y = (y % 16) < 4
    rgb[band_x] = rgb[band_x] * 0.6 + np.array([150, 40, 40]) * 0.4
    rgb[band_y] = rgb[band_y] * 0.6 + np.array([150, 40, 40]) * 0.4
    rgb[band_x & band_y] = np.array([120, 50, 60])
    rgb *= (1.0 + noise(0.05) + smooth_noise(4, 0.06))[..., None]
    save("blanket", rgb)


def rug():
    y, x = np.mgrid[0:S, 0:S]
    d = np.maximum(np.abs(x - 31.5), np.abs(y - 31.5))
    rings = (d.astype(int) // 5) % 3
    cols = np.array([[120, 40, 36], [170, 130, 70], [60, 40, 50]], dtype=np.float32)
    rgb = cols[rings]
    rgb *= (1.0 + noise(0.08))[..., None]
    save("rug", rgb)


def metal():
    y, x = np.mgrid[0:S, 0:S]
    v = 1.0 + np.sin(y * 3.1) * 0.02 + noise(0.04) + smooth_noise(4, 0.06)
    save("metal", colorize(v, (150, 152, 156)))


def counter():
    v = 1.0 + noise(0.1) + smooth_noise(4, 0.04)
    speck = rng.random((S, S)) > 0.93
    v[speck] *= 0.6
    save("counter", colorize(v, (200, 196, 184)))


def poster():
    y, x = np.mgrid[0:S, 0:S]
    rgb = np.zeros((S, S, 3)) + np.array([30, 20, 40])
    # zon/maan
    d = np.hypot(x - 32, y - 24)
    rgb[d < 14] = [220, 120, 60]
    # bergen
    m = y > (44 - np.abs(((x * 7) % 40) - 20) * 0.9)
    rgb[m] = [40, 30, 60]
    rgb[y > 52] = [16, 10, 20]
    rgb *= (1.0 + noise(0.05))[..., None]
    rgb[:2, :] = rgb[-2:, :] = rgb[:, :2] = rgb[:, -2:] = [230, 225, 210]
    save("poster", rgb)


def plastic(name, color):
    v = 1.0 + noise(0.03) + smooth_noise(3, 0.04)
    save(name, colorize(v, color))


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    print("Textures maken in", os.path.abspath(OUT))
    wood_floor()
    carpet()
    tile("bath_tile", (190, 205, 205), (110, 116, 112), n=4)
    checker_floor()
    wallpaper()
    wall_plain()
    wall_bedroom()
    ceiling()
    wood_furniture("wood_light", (160, 120, 78))
    wood_furniture("wood_dark", (84, 56, 40))
    wood_furniture("wood_white", (200, 196, 186))
    fabric("fabric_couch", (84, 96, 70), 0.12)
    fabric("fabric_sheet", (200, 200, 190), 0.05)
    fabric("fabric_pillow", (215, 210, 195), 0.04)
    fabric("fabric_parent", (140, 110, 100), 0.06)
    blanket()
    rug()
    metal()
    counter()
    poster()
    plastic("plastic_black", (30, 30, 32))
    plastic("plastic_white", (215, 215, 210))
    plastic("ceramic", (225, 228, 226))
    print("Klaar!")
