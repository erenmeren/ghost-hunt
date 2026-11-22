# Ghost Hunt

Ters Pac-Man: sen hayaletsin, Pac-Man kendi kendine oynuyor ve yemleri bitirmeye çalışıyor.
Flutter ile yazıldı; iOS, Android ve web'de çalışıyor.

## Modlar

| Mod  | Görünüm | İpucu |
|------|---------|-------|
| Easy | Klasik üstten 2D | Her şey ekranda |
| Hard | Hayaletin gözünden 3D | Pac-Man'in duvarların üstünden görünen ışık huzmesi (yedikçe kalp gibi hızlanıp parlıyor), yakınlığa ve yöne göre "waka" sesi, haritada yenmiş yemlerin izi. Yön oku yok. |
| Hell | 3D | Hiçbiri. Haritada sadece duvarlar ve sen. |

Pac-Man 3 canla başlar. Canları biterse sen kazanırsın, yemleri bitirirse o kazanır. Kazanınca seviye atlanır ve Pac-Man daha hızlı ve daha zeki olur.

## Çalıştırma

```bash
flutter run -d chrome     # web
flutter run               # bağlı telefon / simülatör
flutter test
```

Web'de hızlı test için menüyü atlayıp doğrudan oyuna girebilirsin: `?mode=hard&level=2`.

Ses efektleri `tool/gen_sounds.py` ile üretiliyor (`python3 tool/gen_sounds.py`).

## Yapı

- `lib/game/` — saf oyun mantığı (labirent, hareket, Pac-Man yapay zekası, hayaletler). Flutter'a bağımlı değil, test edilebilir.
- `lib/ui/` — 2D çizici, raycaster (3D), mini harita, oyun ekranı.
- `lib/audio/` — ses efektleri.
