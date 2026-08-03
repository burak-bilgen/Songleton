<div align="center">
  <img src="Songleton/Assets.xcassets/AppIcon.appiconset/icon_512x512@2x.png" width="128" height="128" alt="Songleton app icon" />

  # Songleton ✨

  **The Ultimate Native macOS Music Companion & Cinema Ambient Mode**

  [![macOS 14+](https://img.shields.io/badge/macOS-14%2B-111827?style=for-the-badge&logo=apple&logoColor=white)](https://www.apple.com/macos/)
  [![Swift](https://img.shields.io/badge/Swift-5.9-orange?style=for-the-badge&logo=swift&logoColor=white)](https://www.swift.org/)
  [![SwiftUI](https://img.shields.io/badge/SwiftUI-Native-6D5DFB?style=for-the-badge&logo=swift&logoColor=white)](https://developer.apple.com/xcode/swiftui/)
  [![Tests](https://img.shields.io/badge/tests-20%20passing-20C997?style=for-the-badge)](Makefile)
  [![License](https://img.shields.io/badge/license-MIT-38BDF8?style=for-the-badge)](LICENSE)
</div>

---

**Songleton** is a hyper-polished, lightweight, and blazingly fast native macOS app that transforms your everyday music listening experience across **Spotify** and **Apple Music**. 

From a subtle, one-hover menu bar controller to an immersive **Full-Screen Cinema Ambient Mode** with retro CRT TV effects, rotating vinyl records, and live synced lyrics—Songleton brings your music to life without interrupting your workflow.

---

## 🌟 Key Features

### 🎬 Cinema Ambient Mode
Transform your Mac display into an audiophile music shrine.
- **Retro CRT TV Animations**: Nostalgic CRT beam turn-on and turn-off beam-collapse animations.
- **3 Dynamic Visual Themes**:
  - 💿 **Vinyl Record**: Realistic vinyl grooves, light glare sheen, speed strobe ring, and continuous rotation that freezes in place when paused.
  - 📼 **Retro Cassette Tape**: Dual rotating spools and detailed vintage cassette casing.
  - 🧊 **Pure Glass**: Modern glassmorphic artwork float with deep ambient lighting.
- **Philips Ambilight Heartbeat Aura**: Dynamic background illumination pulsing to the rhythm of your music.
- **Off-Screen Track Slide Transitions**: Track artwork and titles slide 100% across physical monitor boundaries.
- **Integrated Desk Clock & Calendar**: Clean timestamp and date display for desk setups.
- **Sleep Timer Menu**: Dropdown timer (Off, 15m, 30m, 45m, 60m) that automatically pauses music and powers off Ambient Mode.

### 🎤 Real-Time Synced Lyrics
- **Automatic Live Lyrics**: Powered by LRCLIB and Genius engines.
- **Auto-Scrolling Engine**: Smoothly centers the currently active lyric line matching exact playback position.
- **Multi-Line Title Wrapping**: Long track titles automatically scale and wrap without truncation.

### 🎨 Smart HSL Vibrant Color Engine
- **No Muddy Colors**: Uses an intelligent HSL color picker that filters out murky tones and extracts the most vibrant hue from album artwork.
- **Neon Accent Boosting**: Automatically tunes buttons, progress bars, and glows with high-saturation neon accents.

### 🖱️ Mouse Gestures & Menu Bar Companion
- **Scroll Wheel Volume**: Scroll over the menu bar icon to adjust system volume instantly.
- **Hover Panel**: One-hover quick player with progress bar, volume control, history list, and playlists.
- **Always-On Menu Bar**: Stays active 24/7 in your menu bar.

### ⌨️ Pro Keyboard Shortcuts
| Shortcut | Action |
| :--- | :--- |
| `Space` | Toggle Play / Pause |
| `←` / `→` | Previous / Next Track |
| `↑` / `↓` | Volume Up / Down (+10% / -10%) |
| `ESC` | Exit Ambient Mode (triggers CRT TV turn-off) |
| `L` | Toggle Real-Time Synced Lyrics |
| `T` | Cycle Theme Mode (Vinyl ↔ Cassette ↔ Glass) |

---

## 📥 Download and Install

1. Download the latest release (`Songleton-1.0.dmg`).
2. Open the disk image and drag **Songleton.app** into your `Applications` folder.
3. Launch Songleton and grant initial macOS Automation permissions for Spotify / Apple Music.
4. Access Ambient Mode anytime from the right-click menu or hover panel!

---

## 🛠️ Build from Source

```bash
git clone https://github.com/your-repo/Songleton.git
cd Songleton

# Build and run the app
make run

# Run unit test suite
make test

# Generate LLVM code coverage report
make coverage

# Build production release DMG
make dmg
```

---

## 🔒 Privacy & Security

- **100% Local & Private**: No analytics, tracking, or user accounts.
- **Native Automation**: Interacts with local Spotify and Apple Music desktop apps via Apple Events.
- **Optional Network Use**: Synced lyrics queries metadata against public LRCLIB servers without uploading user data.

---

## 📄 License

Distributed under the MIT License. See [LICENSE](LICENSE) for details.
