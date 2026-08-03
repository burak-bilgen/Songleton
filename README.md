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

Karmaşık ayarlarla uğraşmadan, şarkıyı kimin söylediğini menü çubuğundan anında görün, fare tekerleğinizle sesi ayarlayın ya da tam ekrana geçip arkada dönen plağın ve akan şarkı sözlerinin tadını çıkarın!

---

### 🎨 Öne Çıkan Havalı Özellikler

#### 💿 Tam Ekran Ambient (Ortam) Modu
Masada çalışırken veya odanızda müzik dinlerken Mac ekranınızı büyüleyici bir müzik çalar ekranına dönüştürür.
- **Nostaljik CRT TV Efektleri**: Eski tüplü televizyonların gözü yormayan, tatlı açılış ve kapanış ışık hüzmesi animasyonları.
- **3 Farklı Görsel Tema**:
  - 💿 **Vinil Plak**: Dönüş ışık süzmesi, hız noktaları ve şarkı durduğunda olduğu yerde donan gerçekçi plak gövdesi.
  - 📼 **Kaset Çalar**: Çift makarası dönen nostaljik 90'lar kaset çalar tasarımı.
  - 🧊 **Cam (Pure Glass)**: Albüm kapağının derinlik ve cam efektiyle parladığı modern tasarım.
- **Philips Ambilight Ritim Işığı**: Şarkının ritmine göre arka planda tatlı tatlı parlayan renk aurası.
- **Ekran Dışı Şarkı Geçişleri**: Şarkı değiştiğinde albüm kapakları ekranın en dışından süzülerek gelir.
- **Masa Saati & Takvim**: Çalışma masanızda saat ve tarih göstergesi.
- **Uyku Zamanlayıcısı (Sleep Timer)**: 15, 30, 45 veya 60 dakika sonra müziği otomatik durdurup ekranı kapatır.

#### 🎤 Anlık Canlı Şarkı Sözleri (Synced Lyrics)
- **Ritimle Kayan Sözler**: Müziğin anlık saniyesiyle birebir senkronize şekilde kayan canlı şarkı sözleri.
- **Taşmayan Başlıklar**: Uzun şarkı isimleri veya sanatçı adları asla kesilmez (`...` olmaz), ekrana göre otomatik boyutlanır.

#### 🎨 Canlı & Parlak Renk Motoru (Smart HSL Engine)
- **Çamur Tonlara Son**: Albüm kapaklarındaki mat ve çamurumsu kahverengi tonları filtreler; kapağın en canlı ve parlak ana rengini seçer.
- **Neon Düğmeler**: Düğmeler, kaydırma çubukları ve ışık efektleri her zaman canlı ve göz alıcı renklerde parlar.

#### 🖱️ Fare Jestleri & Menü Çubuğu Kontrolü
- **Tekerlekle Ses Ayarı**: Menü çubuğundaki Songleton simgesinin üzerine gelip fare tekerleğini çevirerek sesi anında değiştirin.
- **Sürekli Aktif Menü Çubuğu**: Ambient moddan çıksanız bile Songleton menü çubuğunuzda 7/24 hazır bekler.

---

### ⌨️ Klavye Dostu Kısayollar

| Kısayol | Ne İşe Yarar? |
| :--- | :--- |
| `Space` | Müziği Çal / Duraklat |
| `←` / `→` | Önceki / Sonraki Şarkı |
| `↑` / `↓` | Sesi Artır / Azalt (%10) |
| `ESC` | Ambient Moddan Çık (CRT Kapanış Animasyonu) |
| `L` | Canlı Şarkı Sözlerini Aç / Kapat |
| `T` | Temayı Değiştir (Plak ↔ Kaset ↔ Cam) |

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
