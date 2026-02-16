#!/usr/bin/env python3
"""
App Store talab qiladi: ilova ikonkalarida alpha (shaffoflik) bo'lmasligi kerak.
Bu skript barcha PNG ikonkalarni oq fon ustiga qo'yib, shaffof emas qiladi.
Ishlatish: python3 scripts/make_icons_opaque.py
"""
import os
import sys

try:
    from PIL import Image
except ImportError:
    print("Pillow o'rnatilishi kerak: pip3 install Pillow")
    sys.exit(1)

# Driver loyiha root
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DRIVER_ROOT = os.path.dirname(SCRIPT_DIR)

# iOS App Icon katalogi
IOS_APPICON_DIR = os.path.join(
    DRIVER_ROOT, "ios", "Runner", "Assets.xcassets", "AppIcon.appiconset"
)
# Oq fon (sRGB) - App Store tavsiyasi
BG_COLOR = (255, 255, 255)


def make_opaque(image_path: str) -> bool:
    """PNG faylni shaffof emas qiladi (oq fon). Alpha bor bo'lsa True qaytaradi."""
    try:
        img = Image.open(image_path)
        if img.mode in ("RGBA", "LA", "P"):
            if img.mode == "P":
                img = img.convert("RGBA")
            background = Image.new("RGB", img.size, BG_COLOR)
            if img.mode == "LA":
                background.paste(img, mask=img.split()[1])
            else:
                background.paste(img, mask=img.split()[-1])
            background.save(image_path, "PNG")
            return True
        return False
    except Exception as e:
        print(f"Xato {image_path}: {e}")
        return False


def main():
    if not os.path.isdir(IOS_APPICON_DIR):
        print(f"Topilmadi: {IOS_APPICON_DIR}")
        sys.exit(1)
    changed = 0
    for name in os.listdir(IOS_APPICON_DIR):
        if name.lower().endswith(".png"):
            path = os.path.join(IOS_APPICON_DIR, name)
            if make_opaque(path):
                changed += 1
                print(f"O'zgartirildi (shaffof emas): {name}")
    print(f"Tugadi. {changed} ta fayl yangilandi.")


if __name__ == "__main__":
    main()
