"""Menu backdrop GUIMain 17 (5_0017.png) as a seamlessly tiling linen surface.

The engine tiles this sprite to fill the screen, so a scene (sky over hills) shows hard bands in large windows.
Noise is shaped in the frequency domain, which makes it periodic: the tile joins itself on every edge.
The hills and village live in the card art (5_0018), so the backdrop stays a calm surface.
Run: tools/.venv/bin/python tools/backdrop_tile.py
"""
from pathlib import Path

import numpy as np
from PIL import Image, PngImagePlugin

OUT = Path(__file__).resolve().parent.parent / "Modding graphics" / "5_0017.png"
W, H = 700, 800                      # original sprite size, kept
BASE = np.array([243.0, 231.0, 203.0])  # mean of the old sky, so the card sits on the same colour
MARK = "friendly-texture"               # texture_pass.py skips files carrying this chunk


def periodic_noise(rng, shape, falloff, aniso=1.0):
    """Gaussian noise low-passed in the frequency domain: periodic, zero mean, unit std."""
    n = rng.standard_normal(shape)
    fy = np.fft.fftfreq(shape[0])[:, None]
    fx = np.fft.rfftfreq(shape[1])[None, :]
    r = np.sqrt((fx * aniso) ** 2 + fy ** 2)
    f = np.fft.irfft2(np.fft.rfft2(n) * np.exp(-(r / falloff) ** 2), s=shape)
    return (f - f.mean()) / f.std()


def main():
    rng = np.random.default_rng(17)
    mottle = periodic_noise(rng, (H, W), 0.012)            # soft cloudy unevenness of hand-made paper
    fibres = periodic_noise(rng, (H, W), 0.08, aniso=6.0)  # short horizontal linen fibres
    grain = periodic_noise(rng, (H, W), 0.45)              # fine tooth
    lum = 1.0 + 0.009 * mottle + 0.007 * fibres + 0.006 * grain
    rgb = np.clip(BASE[None, None, :] * lum[..., None], 0, 255).astype(np.uint8)
    img = np.dstack([rgb, np.full((H, W), 255, np.uint8)])

    # The tile must join itself: compare each edge with the opposite one against a typical neighbour step
    a = img[..., :3].astype(int)
    step = np.abs(np.diff(a, axis=0)).mean()
    assert np.abs(a[0] - a[-1]).mean() < 2 * step and np.abs(a[:, 0] - a[:, -1]).mean() < 2 * step

    info = PngImagePlugin.PngInfo()
    info.add_text(MARK, "1")
    Image.fromarray(img, "RGBA").save(OUT, pnginfo=info)
    print(f"wrote {OUT} {W}x{H}, luminance spread {lum.min():.3f}..{lum.max():.3f}")


if __name__ == "__main__":
    main()
