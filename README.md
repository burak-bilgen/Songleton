<div align="center">

  <img src="Songleton/Assets.xcassets/AppIcon.appiconset/icon_512x512@2x.png" width="128" height="128" alt="Songleton Icon" style="border-radius: 28px; box-shadow: 0 12px 32px rgba(0,0,0,0.5);" />

  # Songleton
  **The Ultimate Native macOS Menu Bar Companion for Spotify & Apple Music**

  [![macOS 14.0+](https://img.shields.io/badge/macOS-14.0%2B-blue?style=for-the-badge&logo=apple&logoColor=white)](https://apple.com)
  [![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange?style=for-the-badge&logo=swift&logoColor=white)](https://swift.org)
  [![SwiftUI](https://img.shields.io/badge/SwiftUI-Liquid%20Glass-purple?style=for-the-badge&logo=swift&logoColor=white)](https://developer.apple.com/xcode/swiftui/)
  [![License MIT](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)](LICENSE)
  [![Build & Test](https://img.shields.io/badge/Tests-6%2F6%20Passed-brightgreen?style=for-the-badge&logo=github-actions&logoColor=white)](Makefile)

  <p align="center">
    <b>Songleton</b> brings your music directly to your macOS Menu Bar with a breathtaking Liquid Glass interface, synchronized real-time lyrics, instant volume control, dynamic platform accent themes, and zero footprint.
  </p>

</div>

---

## ✨ Features at a Glance

### 🎵 Pure Native Menu Bar Integration
- **Live Track Marquee:** Real-time track name and artist scrolling right in your menu bar.
- **Sleep Mode (`zZz`):** Automatically hides or displays a minimalist sleeping state when Spotify/Apple Music is closed.
- **Click-to-Copy:** Click any track label to instantly copy `"Artist - Track Name"` to your clipboard.

### 🍷 Liquid Glass Hover Panel
- **Zero-Click Peek:** Hover over the menu bar icon to instantly reveal album cover, track progress, volume controls, and playback actions.
- **Pure Jet Black Aesthetics:** Designed specifically for modern OLED and Retina displays with silky smooth Apple `.spring` physics.
- **Accordion Synced Lyrics:** Expand real-time synchronized karaoke-style lyrics with dynamic offset compensation.

### 🎚️ Smart Popovers & Gestures
- **Discrete Volume Slider:** Dedicated volume popover for smooth volume adjustment without opening full music apps.
- **Smart Toast Notifications (HUD):** Non-intrusive HUD notifications on song changes that automatically suppress themselves when the hover menu is open to prevent UI collision.

### 🖤 Minimalist OLED Settings Window
- **Fixed & Centered Panel:** Beautiful, fixed-size centered settings dialog following pure OLED monochrome design principles.
- **Full Customizability:**
  - **Launch at Login:** Native `SMAppService` integration for instant launch when your Mac boots up.
  - **Show Artist in Menu Bar:** Toggle between full `"Artist - Song"` or clean `"Song Name"` display.
  - **Dynamic Color Theme:** Seamlessly switch accents between Spotify Green (`#1DB954`) and Apple Music Pink (`#FA243C`).
  - **Progress Bar Toggle:** Show or hide live playback seek bars.
  - **Lyrics Offset Sync:** Calibrate real-time lyrics delay from `-3.0s` to `+3.0s`.

---

## 🎨 Design Principles

- **Liquid Glass & OLED Jet Black:** Dark-mode native controls with high-contrast typography and subtle glassmorphic borders.
- **Spring Animations:** Native macOS fluid response times with natural inertia and zero lag.
- **Localization First:** Full bilingual support for **English** and **Turkish** out of the box (`Localizable.xcstrings`).

---

## 🚀 Getting Started

### Prerequisites
- macOS 14.0 (Sonoma) or newer.
- Xcode 15.0+ (if building from source).
- Spotify or Apple Music desktop client.

### Building & Running from Source

```bash
# Clone the repository
git clone https://github.com/your-username/Songleton.git
cd Songleton

# Build and run the app immediately
make run
```

### Running Unit Tests

Songleton includes a lightweight, zero-dependency native Swift unit testing suite:

```bash
# Run unit tests
make test
```

### Build Targets in Makefile

| Command | Description |
| :--- | :--- |
| `make run` | Compiles and launches the debug application |
| `make test` | Executes the 6-suite Unit Test runner |
| `make fresh` | Cleans `UserDefaults`, resets TCC automation permissions, and launches fresh |
| `make dmg` | Generates a clean production release `.dmg` installer in `build/` |
| `make clean` | Cleans Xcode build artifacts and temporary data |

---

## 🔒 Permissions & Security

Songleton uses macOS AppleScript Automation permissions (`NSAppleEventsUsageDescription`) to communicate locally with Spotify and Apple Music.

- **Zero Cloud Tracking:** All data is processed 100% locally on your Mac.
- **No Background Battery Drain:** Listens only when media players are active.

---

## 🛠️ Architecture

```
Songleton/
├── App/
│   ├── SongletonApp.swift         # SwiftUI App Entry point
│   ├── MenuBarManager.swift       # NSStatusItem & Popover Lifecycle
│   └── HUDToastManager.swift      # Toast notification manager
├── Models/
│   ├── NowPlayingModel.swift      # Central state store & playback engine
│   ├── SettingsModel.swift        # User preferences & persistence
│   ├── MediaController.swift      # Spotify / Apple Music AppleScript drivers
│   └── LyricsModel.swift          # LrcLib real-time lyrics parser
├── Views/
│   ├── UnifiedHoverPanelView.swift# Main Liquid Glass hover interface
│   ├── SettingsView.swift         # OLED Minimalist preferences window
│   ├── SyncedLyricsView.swift     # Synchronized karaoke lyrics component
│   └── MenuBarMainLabelView.swift # Status bar label & animation
└── SongletonTests/                # Native Swift unit test suite
```

---

## 📄 License

Distributed under the MIT License. See `LICENSE` for more information.

<div align="center">
  <br/>
  Crafted with ♥ for macOS power users.
</div>
