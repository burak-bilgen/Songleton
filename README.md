<div align="center">
  <img src="Songleton/Assets.xcassets/AppIcon.appiconset/icon_512x512@2x.png" width="128" height="128" alt="Songleton app icon" />

  # Songleton ✨

  **Mac'inizde müzik dinleme deneyimini zirveye çıkaran, menü çubuğuna gizli tam ekran görsel şölen!**

  [![macOS 14+](https://img.shields.io/badge/macOS-14%2B-111827?style=for-the-badge&logo=apple&logoColor=white)](https://www.apple.com/macos/)
  [![Swift](https://img.shields.io/badge/Swift-5.9-orange?style=for-the-badge&logo=swift&logoColor=white)](https://www.swift.org/)
  [![SwiftUI](https://img.shields.io/badge/SwiftUI-Native-6D5DFB?style=for-the-badge&logo=swift&logoColor=white)](https://developer.apple.com/xcode/swiftui/)
  [![Tests](https://img.shields.io/badge/tests-20%20passing-20C997?style=for-the-badge)](Makefile)
  [![License](https://img.shields.io/badge/license-MIT-38BDF8?style=for-the-badge)](LICENSE)
</div>

---

### 🔥 Songleton Nedir?

**Songleton**, Spotify veya Apple Music kullanırken arka planda sessizce çalışan, Mac'inizin menü çubuğuna (Menu Bar) yerleşen ve tek tıkla ekranınızı nostaljik bir müzik stüdyosuna dönüştüren **ultra hızlı ve yerel macOS müzik yardımcısıdır.**

Karmaşık ayarlarla uğraşmadan, şarkıyı kimin söylediğini menü çubuğundan anında görün, fare hareketleriyle sesi ayarlayın ya da tam ekrana geçip arkada dönen plağın ve akan şarkı sözlerinin tadını çıkarın!

---

### 🎨 Öne Çıkan Havalı Özellikler

#### 💿 Tam Ekran Sinematik Ambient (Ortam) Modu
Masada çalışırken veya odanızda müzik dinlerken Mac ekranınızı büyüleyici bir müzik çalar ekranına dönüştürür.
- **Sinematik Açılış & Mercek Efekti**: Ekran 0.82 ölçekten yaylanarak büyür (`.spring`), 24px mercek buğusu (Lens Blur) süzülerek kristal netliğe kavuşur.
- **Nostaljik CRT TV Efektleri**: Eski tüplü televizyonların gözü yormayan kapanış ışık hüzmesi animasyonları.
- **3 Farklı Görsel Tema**:
  - 💿 **Vinil Plak**: Dönüş ışık süzmesi, hız noktaları ve şarkı durduğunda olduğu yerde donan gerçekçi plak gövdesi.
  - 📼 **Kaset Çalar**: Çift makarası dönen nostaljik 90'lar kaset çalar tasarımı.
  - 🧊 **Cam (Pure Glass)**: Albüm kapağının derinlik ve cam efektiyle parladığı modern tasarım.
- **Philips Ambilight Ritim Işığı**: Şarkının ritmine göre arka planda tatlı tatlı parlayan renk aurası.
- **Uyku Zamanlayıcısı (Sleep Timer)**: Müziği otomatik durdurup ekranı kapatan dahili zamanlayıcı.

#### 🔔 Odak Çalmayan Sağ Üst Bildirimler (Non-Activating Toast)
- **Yazı Yazmayı Bölmez**: Kod yazarken, mesajlaşırken veya tarayıcıda gezinirken yeni şarkı bildirimi çıktığında **klavye odağınız asla bozulmaz** (`isKeyWindow = false`).
- **Sağ Üst Yerleşim & Ambilight Aura**: Sağ üst köşede renkli HSL aurası ve cam kaplamasıyla süzülür.

#### 🖱️ Akıllı Fare & Ekran Kenarı Jestleri (Gestures)
- **Direkt Sağ Tık Kestirmesi**: Menü çubuğu ikonuna **doğrudan Sağ Tık (Right-Click)** yaparak Ambient Mode'a anında geçin! (Option + Sağ Tık: Ayarlar & Çıkış menüsü).
- **Kapağa Çift Tıklama**: Hover panelindeki albüm kapağına **Çift Tıklayarak (Double-Click)** Ambient Mode'a geçiş yapın.
- **Sağa / Sola Ekran Vurma**: Fareyi ekranın sol/sağ kenarına vurup 0.5s durarak **Önceki / Sonraki Şarkı**'ya geçin.
- **Yukarı Ekran Vurma**: Fareyi ekranın en üstüne vurup 0.5s durarak **Müziği Oynatın / Durdurun**.
- **Sol + Sağ Tık Canlı Ses Ayarı**: İki fare tuşuna aynı anda basarak (veya ⌘ + ⌥) fareyi yukarı/aşağı sürükleyip **Canlı Ses Düzeyini** ayarlayın.
- **Bağımsız Ayarlar**: İstediğiniz jest grubunu Ayarlar ekranından bağımsız olarak açıp kapatabilirsiniz.

---

### ⌨️ Klavye Dostu Kısayollar (Ambient Mode)

| Kısayol | Ne İşe Yarar? |
| :--- | :--- |
| `Space` | Müziği Çal / Duraklat |
| `←` / `→` | Önceki / Sonraki Şarkı |
| `↑` / `↓` | Sesi Artır / Azalt (%10) |
| `ESC` | Ambient Moddan Çık (CRT Kapanış Animasyonu) |
| `L` | Canlı Şarkı Sözlerini Aç / Kapat |
| `T` | Temayı Değiştir (Plak ↔ Kaset ↔ Cam) |

---

### 📱 5 Adımlı İnteraktif Onboarding
Uygulama ilk kez açıldığında ekranın tam ortasında başlayan ve tüm kestirmeleri, fare hareketlerini, klavye kısayollarını görsellerle anlatan interaktif açılış rehberi.

---

### 🛡️ Gizlilik ve Güvenlik

- **%100 Yerel ve Güvenli**: Hiçbir üyelik, kayıt veya takip kodu içermez.
- **Sadece Söz Çekimi**: Sadece canlı şarkı sözlerini bulmak amacıyla şarkı adı ve sanatçı bilgisi açık kaynaklı [LRCLIB](https://lrclib.net/) servisine sorulur.
- **Kişisel Veri Yüklenmez**: Şifreleriniz, dinleme geçmişiniz veya kişisel verileriniz asla Mac'inizin dışına çıkmaz.

---

### 🚀 Kurulum & Kaynak Koddan Derleme

```bash
git clone https://github.com/your-repo/Songleton.git
cd Songleton

# Derle ve Uygulamayı Başlat
make run

# Testleri Çalıştır
make test

# Release DMG Paketle
make dmg
```

---

### 📄 Lisans

Songleton, **MIT Lisansı** altında özgürce dağıtılmaktadır. Detaylar için [LICENSE](LICENSE) dosyasına göz atabilirsiniz.
