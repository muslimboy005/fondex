# Driver ilova skriptlari

## App Store uchun ikonkalarni shaffof emas qilish

Apple App Store ilova ikonlarida alpha (shaffoflik) qabul qilmaydi. Yangi ikon qo'shganda yoki rad etilganda quyidagini ishlating:

```bash
# Pillow birinchi marta kerak bo'lsa: pip3 install --user Pillow
python3 scripts/make_icons_opaque.py
```

Skript `ios/Runner/Assets.xcassets/AppIcon.appiconset/` dagi barcha PNG fayllarni oq fon ustiga qo'yadi.

Android: adaptive icon (foreground + background) shaffof foregroundni qo'llab-quvvatlaydi, alohida o'zgartirish kerak emas.
