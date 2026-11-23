# 👻 Ghost Hunt

**Ters Pac-Man.** Bu sefer hayalet sensin. Pac-Man kendi kendine oynuyor, yemleri bitirmeye çalışıyor ve senden kaçıyor. Görevin onu yakalamak.

Flutter ile yazıldı. Tek kod tabanıyla **web, iOS ve Android**'de çalışıyor.

▶️ **Tarayıcıda oyna:** https://erenmeren.github.io/ghost-hunt/

| Easy (2D) | Hard (3D) | Hell, zıplarken |
|---|---|---|
| ![Easy](docs/easy.png) | ![Hard](docs/hard.png) | ![Hell](docs/hell-jump.png) |

## Modlar

| Mod | Görünüm | Elindeki ipuçları |
|------|---------|-------|
| **Easy** | Klasik, üstten 2D | Her şey ekranda. Güç hapı yiyen Pac-Man seni kovalar. |
| **Hard** | Hayaletin gözünden, birinci şahıs 3D | Pac-Man'in duvarların üstünden yükselen sarı ışık huzmesi. Huzme yem yedikçe kalp atışı gibi hızlanıp parlıyor. Yönüne ve uzaklığına göre değişen "waka" sesi var. Sağ altta açılıp kapanan haritada yenmiş yemlerin izi görünüyor. Yön oku yok. |
| **Hell** | 3D, kırmızı, karanlık, titreyen ışık | Görsel ipucu yok, haritada sadece duvarlar ve sen varsın. Sadece ses var ve **zıplayıp** duvarların üstünden bakabilirsin. |

- Pac-Man 3 canla başlar. Canlarını sen ve diğer hayaletler bitirirseniz kazanırsınız. Pac-Man yemleri bitirirse o kazanır.
- Kazandıkça seviye atlarsın. Her seviyede Pac-Man daha hızlı ve daha zeki oluyor.
- Diğer üç hayalet de oyunda, kendi kişilikleriyle Pac-Man'i kovalıyor.

## Para, shop ve paketler

Para tamamen oyun içinde, gerçek parayla hiçbir şey satılmıyor.

- **Kazanma:** Pac-Man'i sen yakalarsan 20–40 🪙 alırsın; ne kadar erken yakalarsan o kadar çok. Takım arkadaşın yakalarsa 5 🪙. Bölümü bitirince bonus var.
- **Mod çarpanı:** Easy ×1, Hard ×2, Hell ×4. Yeni oyuncu 150 🪙 ile başlar.
- **Kayıt:** Para ve satın aldıkların cihazda saklanıyor (webde tarayıcının localStorage'ında).

| Paket | Fiyat | Etki |
|---|---|---|
| ⚡ Hız | 60 | 5 saniye %40 daha hızlı |
| 👻 Görünmezlik | 120 | 5 saniye Pac-Man seni görmez, senden kaçmaz |
| 🧱 Duvardan geçme | 150 | 3 saniye iç duvarlardan geçersin |
| 📡 Sonar | 90 | 2 saniye Pac-Man'in ışığı ve haritadaki yeri görünür (Hard/Hell) |

Kalıcı yükseltmeler de var, her biri 3 seviyeli: 🏃 temel hız, 👂 Pac-Man'i daha uzaktan duyma, 🎒 bir bölümde fazladan paket kullanma hakkı. Bir bölümde varsayılan olarak en fazla 2 paket kullanılabiliyor.

## Kontroller

| | Klavye | Telefon |
|---|---|---|
| Dön (bir sonraki kavşakta) | ← → | Sola/sağa kaydır veya dönüş düğmeleri |
| Geri dön | ↓ | Aşağı kaydır veya ↶ düğmesi |
| Zıpla (Hell) | Boşluk | ⏫ düğmesi |
| Paket kullan | 1–4 | Soldaki paket düğmeleri |
| Harita aç/kapat | M | Sağ alttaki düğme |
| Duraklat | P / Esc | ⏸ |

## Çalıştırma

[Flutter](https://docs.flutter.dev/get-started/install) 3.x gerekiyor.

```bash
flutter pub get
flutter run -d chrome          # web
flutter run                    # bağlı telefon veya simülatör
flutter test                   # testler
flutter build web              # build/web altına statik site üretir
```

Webde menüyü atlayıp doğrudan bir moda girmek için adrese parametre ekleyebilirsin: `?mode=easy|hard|hell&level=2`.
3D görüntü takılırsa `?renderer=ray` ile daha hafif olan eski çiziciye geçebilirsin.

Ses efektleri koddan sentezleniyor: `python3 tool/gen_sounds.py` dosyaları `assets/sounds/` altına yazar.

## Nasıl çalışıyor?

- **Pac-Man'in yapay zekası** (`lib/game/pacman_ai.dart`): En yakın yemlere yol arıyor ve hayaletlerin nereye ulaşabileceğini gösteren bir tehlike haritası çıkarıyor. Seviye arttıkça daha uzağı görüyor ve daha az hata yapıyor. Güç hapı yediğinde rolleri değiştirip seni kovalıyor.
- **3D görüntü** (`shaders/scene.frag`): Oyun motoru kullanılmıyor. Labirent küçük bir dokuya yazılıyor. Ekrandaki her pikselin rengi, ekran kartında çalışan bir fragment shader'ın gönderdiği ışınla hesaplanıyor. Pac-Man sahnedeki tek ışık kaynağı, duvarlara gölge düşürüyor. Zıplarken kamera duvarların üstüne çıkabiliyor.
- **Yedek çizici** (`lib/ui/raycast_painter.dart`): Shader desteği olmayan ortamlar için Wolfenstein tarzı klasik raycaster.

```
lib/
  game/      oyun mantığı: labirent, hareket, Pac-Man AI, ekonomi (Flutter'dan bağımsız, test edilebilir)
  ui/        2D çizici, 3D shader sahnesi, raycaster, mini harita, oyun ve shop ekranları
  audio/     ses efektleri
shaders/     3D sahne (GLSL)
test/        oyun mantığı, ekonomi, widget ve görüntü testleri
tool/        ses üretici
```

## Yol haritası

- [ ] Uçuş paketi
- [ ] Easy için yukarıdan eğik bakan 3D görünüm
- [ ] Görsel tarzın baştan ele alınması (karakter modelleri, kaplamalar, menü)
- [ ] Gerçek telefonlarda performans testi ve App Store / Play Store derlemeleri

## Lisans

[Apache License 2.0](LICENSE)
