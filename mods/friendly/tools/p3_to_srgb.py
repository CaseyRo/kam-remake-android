"""Convert Paper's Display P3 PNG exports to plain sRGB in place and drop the ICC profile.

The engine ignores embedded profiles, so P3-encoded values would show shifted colours.
Usage: python -I p3_to_srgb.py file.png [...]
"""
import io
import sys
from PIL import Image, ImageCms

SRGB = ImageCms.createProfile("sRGB")

for path in sys.argv[1:]:
    im = Image.open(path)
    icc = im.info.get("icc_profile")
    if not icc:
        print(path, "no profile, left as is")
        continue
    src = ImageCms.ImageCmsProfile(io.BytesIO(icc))
    if "P3" not in ImageCms.getProfileDescription(src):
        im.info.pop("icc_profile")
        im.save(path)  # already sRGB values: just drop the tag
        print(path, "already sRGB, tag dropped")
        continue
    im = im.convert("RGBA")
    rgb = ImageCms.profileToProfile(im.convert("RGB"), src, SRGB,
                                    renderingIntent=ImageCms.Intent.RELATIVE_COLORIMETRIC, outputMode="RGB")
    out = rgb.convert("RGBA")
    out.putalpha(im.getchannel("A"))
    out.info.pop("icc_profile", None)
    size = im.size
    out.save(path)  # no icc_profile passed, so none is written
    assert Image.open(path).size == size and "icc_profile" not in Image.open(path).info
    print(path, "-> sRGB")
