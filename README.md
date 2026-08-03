<div align="center">
  <img src="Songleton/Assets.xcassets/AppIcon.appiconset/icon_512x512@2x.png" width="128" height="128" alt="Songleton app icon" />

  # Songleton ✨

  **A hidden-in-the-menu-bar full-screen visual experience that elevates music listening on your Mac!**

  [![macOS 14+](https://img.shields.io/badge/macOS-14%2B-111827?style=for-the-badge&logo=apple&logoColor=white)](https://www.apple.com/macos/)
  [![Swift](https://img.shields.io/badge/Swift-5.0-orange?style=for-the-badge&logo=swift&logoColor=white)](https://www.swift.org/)
  [![SwiftUI](https://img.shields.io/badge/SwiftUI-Native-6D5DFB?style=for-the-badge&logo=swift&logoColor=white)](https://developer.apple.com/xcode/swiftui/)
  [![Tests](https://img.shields.io/badge/tests-22%20passing-20C997?style=for-the-badge)](Makefile)
  [![License](https://img.shields.io/badge/license-MIT-38BDF8?style=for-the-badge)](LICENSE)
</div>

---

### 🔥 What is Songleton?

**Songleton** is an **ultra-fast, fully native macOS music companion** that quietly lives in your Mac's menu bar while you use Spotify or Apple Music, and turns your entire screen into a nostalgic music studio with a single click.

No complicated settings — see who's singing right from the menu bar, adjust the volume with mouse gestures, or go fullscreen and enjoy a spinning vinyl record with flowing lyrics!

---

### 🎨 Highlight Features

#### 💿 Fullscreen Cinematic Ambient Mode
While you work at your desk or listen in your room, Songleton transforms your Mac's display into a captivating music player screen.
- **Cinematic Opening & Lens Effect**: The screen springs in from 0.82 scale (`.spring`) with a 24px lens blur that settles into crystal clarity.
- **Nostalgic CRT TV Effects**: Retro cathode-ray tube closing animations with a gentle light sweep.
- **3 Visual Themes**:
  - 💿 **Vinyl Record**: Realistic record body with rotating light sweep, speed dots, and freeze-on-pause behavior.
  - 📼 **Cassette Deck**: A nostalgic 90s cassette player design with dual spinning reels.
  - 🧊 **Pure Glass**: Modern design where the album art glows with depth and glass effects.
- **Philips Ambilight Rhythm Light**: A color aura that gently pulses with the beat of the song.
- **Sleep Timer**: Built-in timer that automatically stops the music and dims the screen.

#### 🔔 Non-Activating Toast Notifications
- **Never Breaks Your Focus**: When a new track notification appears while you're coding, messaging, or browsing, your **keyboard focus is never stolen** (`isKeyWindow = false`).
- **Top-Right Placement with Ambilight Aura**: Glides in at the top-right corner with a colorful HSL aura and glass coating.

#### 🖱️ Smart Mouse & Gesture Controls
- **Direct Right-Click Shortcut**: **Right-click** the menu bar icon to instantly enter Ambient Mode! (Option + Right-Click: Settings & Quit menu).
- **Double-Click the Artwork**: Double-click the album art in the hover panel to enter Ambient Mode.
- **Rest at the Left / Right Side**: Rest the cursor against the left or right side of the screen for 0.5s to go **Previous / Next track**.
- **Rest at the Top**: Rest the cursor at the very top of the screen for 0.5s to **Play / Pause**.
- **Left + Right Click Live Volume**: Press both mouse buttons simultaneously (or ⌘ + ⌥) and drag up/down to adjust **live volume**.
- **Independent Toggles**: Enable or disable each gesture group independently from the Settings screen.

---

### ⌨️ Keyboard Shortcuts (Ambient Mode)

| Shortcut | Action |
| :--- | :--- |
| `Space` | Play / Pause |
| `←` / `→` | Previous / Next Track |
| `↑` / `↓` | Volume Up / Down (10%) |
| `ESC` | Exit Ambient Mode (CRT closing animation) |
| `L` | Toggle Live Lyrics |
| `T` | Cycle Theme (Vinyl ↔ Cassette ↔ Glass) |

---

### 📱 5-Step Interactive Onboarding
When the app is launched for the first time, an interactive guide starts right in the center of the screen, walking you through all shortcuts, mouse gestures, and keyboard shortcuts with visuals.

---

### 🛡️ Privacy & Security

- **100% Local & Secure**: No membership, registration, or tracking code.
- **Lyrics Only**: Track name, artist, album, and duration are sent to the open-source [LRCLIB](https://lrclib.net/) service solely to fetch live lyrics.
- **Artwork**: Album artwork is loaded from the media player's own source (Spotify/Apple Music).
- **No Personal Data Uploaded**: Your passwords, listening history, or personal data never leave your Mac.

---

### 🚀 Installation & Building from Source

```bash
git clone <repository-url>
cd Songleton

# Build and launch the app
make run

# Run the tests
make test

# Package a release DMG
make dmg
```

### ✅ Quality Checks

```bash
# Unit tests
make test

# Test coverage report
make coverage

# Local debug build without code signing
xcodebuild -project Songleton.xcodeproj -scheme Songleton -configuration Debug build CODE_SIGNING_ALLOWED=NO

# Tests + warnings-as-errors quality gate
make quality
```

GitHub Actions runs these tests and a debug build on every `main` update and pull request.

For distribution, use `make archive` with `DEVELOPER_IDENTITY` to create a signed Xcode archive, `make dmg` to create the DMG, and `make notarize` for Apple notarization. See [RELEASING.md](RELEASING.md) for the full flow.

---

### 📄 License

Songleton is freely distributed under the **MIT License**. See the [LICENSE](LICENSE) file for details.

The bundled **Audiowide** typeface is licensed under the [SIL Open Font License 1.1](https://openfontlicense.org/); see the OFL notice in the font metadata.
