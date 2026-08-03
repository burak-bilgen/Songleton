# Songleton

Songleton is a native macOS music companion that lives in the menu bar and adds a cinematic, full-screen listening experience to Spotify and Apple Music.

It gives you fast playback controls, album artwork, synced lyrics, configurable mouse gestures, ambient visual themes, and a sleep timer without replacing your music player.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-111827?style=for-the-badge&logo=apple&logoColor=white)
![Swift](https://img.shields.io/badge/Swift-5-orange?style=for-the-badge&logo=swift&logoColor=white)
![SwiftUI](https://img.shields.io/badge/SwiftUI-Native-6D5DFB?style=for-the-badge&logo=swift&logoColor=white)
![Tests](https://img.shields.io/badge/tests-23%20passing-20C997?style=for-the-badge)
![License](https://img.shields.io/badge/license-MIT-38BDF8?style=for-the-badge)

## Contents

- [What Songleton Does](#what-songleton-does)
- [Requirements](#requirements)
- [Install and Launch](#install-and-launch)
- [First Launch and Permissions](#first-launch-and-permissions)
- [Daily Use](#daily-use)
- [Ambient Mode](#ambient-mode)
- [Mouse Gestures](#mouse-gestures)
- [Keyboard Shortcuts](#keyboard-shortcuts)
- [Settings](#settings)
- [Lyrics](#lyrics)
- [Troubleshooting](#troubleshooting)
- [Privacy](#privacy)
- [Build and Development](#build-and-development)
- [License](#license)

## What Songleton Does

### Menu bar control center

Songleton stays out of the way until you need it. The menu bar shows the current track and, optionally, the artist. Previous and next buttons can be displayed beside the track label.

The main menu bar item supports these actions:

- Left-click the track area to play or pause.
- Hover over the track area to open the full control panel.
- Right-click to enter Ambient Mode immediately.
- Option-right-click to open the Settings and Quit menu.

### Hover control panel

The hover panel provides:

- Current album artwork, track, artist, and player source.
- Play/pause, previous, and next controls.
- Volume slider and mute control.
- Shuffle and repeat controls where supported by the active player.
- Seekable progress bar with elapsed and remaining time.
- Copyable track information.
- A direct Ambient Mode button.
- A direct Settings button.
- A Quit button that closes Songleton completely.

Double-clicking the album artwork opens Ambient Mode. The panel uses the artwork's dominant color for its visual accents.

### Track change notifications

When the track changes, Songleton can show a non-activating notification in the top-right corner. It does not steal keyboard focus from the application you are using. Notifications can be disabled in Settings.

## Requirements

- macOS 14 or newer.
- Spotify and/or Apple Music installed for playback control.
- Accessibility permission for global mouse gestures.
- Automation permission for each music player you want Songleton to control.
- An internet connection only when fetching lyrics from LRCLIB.

Songleton does not play music itself. Spotify or Apple Music must be running and have a current track available.

## Install and Launch

### From a release

Open the Songleton DMG, drag Songleton to Applications, and launch it. Release builds are Developer ID-signed and notarized by Apple, so macOS opens them without a security warning.

### From source

```bash
git clone <repository-url>
cd Songleton
make
```

`make` builds the Debug target and launches the application. The equivalent explicit command is:

```bash
make run
```

Songleton is a menu bar application, so it may not open a traditional main window after launch.

## First Launch and Permissions

The first launch opens a five-step onboarding flow with an animated welcome, guided feature cards, and permission shortcuts. You can use it to understand the controls and grant the required permissions.

### Automation permission

Automation permission allows Songleton to read the current track and send playback commands to Spotify and Apple Music through macOS Apple Events.

When prompted, allow Songleton to control the player. If you use both players, grant access to both. You can review the status from Settings under Permissions.

### Accessibility permission

Accessibility permission enables global mouse monitoring for edge and volume gestures. Songleton uses this permission to observe mouse movement and button state; it does not need to control other applications' content.

If the permission is not granted during onboarding:

1. Open Songleton Settings.
2. Open the Accessibility permission row.
3. Enable Songleton in System Settings > Privacy & Security > Accessibility.
4. Return to Songleton and try the gesture again.

You can skip permissions and grant them later. Menu bar controls and Ambient Mode can still be used where the corresponding player permission is available.

## Daily Use

1. Start Spotify or Apple Music and play a track.
2. Look for Songleton in the menu bar.
3. Hover over the track label to open the control panel.
4. Use the panel for playback, seeking, volume, shuffle, repeat, and Ambient Mode.
5. Use the edge gestures or keyboard shortcuts when you want hands-free control.

Songleton automatically selects the active player. If both players are running, it prefers the player that is currently playing. If neither is playing, it can use a paused player as a fallback.

## Ambient Mode

Ambient Mode turns the current display into a full-screen music visualizer. It hides the menu bar and Dock while active and restores them when you exit.

### How to enter Ambient Mode

- Click the Ambient button in the hover panel.
- Double-click the album artwork in the hover panel.
- Right-click the main menu bar item.

### Visual themes

Ambient Mode includes three themes. Press `T` to cycle between them or use the theme control in the ambient toolbar.

| Theme | Description |
| --- | --- |
| Vinyl Record | A rotating record player visual with artwork, light sweep, and playback-aware motion. |
| Cassette Tape | A retro cassette deck with spinning reels and a nostalgic hardware feel. |
| Pure Glass | A minimal glass composition focused on artwork glow, depth, and transparency. |

The artwork creates a dynamic ambient aura behind the main visual. Playback state affects motion and the record or cassette pauses naturally when the track is paused.

### Ambient controls

Move the pointer to reveal the toolbar. Depending on the selected state, the toolbar provides:

- Play/pause, previous, and next controls.
- Seek bar with elapsed and total duration.
- Volume control.
- Shuffle and repeat controls.
- Theme selection.
- Live synced lyrics toggle.
- Sleep timer.

Press `ESC` to exit. Songleton uses a CRT-inspired closing animation before returning to the menu bar.

### Sleep timer

Open the sleep timer from the Ambient toolbar and choose a duration. The remaining time is shown while the timer is active. When it expires, Songleton stops playback and dims the experience before leaving Ambient Mode.

## Mouse Gestures

Mouse gestures work globally after Accessibility permission is granted. The cursor must rest inside the relevant screen edge zone until the gesture completes.

### Edge gestures

| Gesture | Action |
| --- | --- |
| Rest at the left edge | Previous track |
| Rest at the right edge | Next track |
| Rest at the top edge | Play or pause |

While an edge gesture is being recognized, a small black-and-white AMOLED cursor orb follows the pointer. Its ring fills as the hold progresses and bursts outward in white when the action is triggered. If the cursor leaves the edge before the hold completes, the orb flashes red and collapses quickly — a cancel cue that is distinct from the success burst. The real cursor is never moved by Songleton.

The default edge hold duration is `0.8s`. The top play/pause gesture is intentionally faster at `0.64s` (80% of the setting). Both values are derived from the Edge hold duration setting, so changing the setting scales the top gesture proportionally.

The edge gesture control is available in Settings under General. It can be adjusted from `0.2s` to `2.0s` in `0.1s` increments.

### Volume gesture

Songleton supports two ways to start a live volume gesture:

- Hold both mouse buttons and drag vertically.
- Hold `Command + Option` and drag vertically.

Drag up to increase the volume and down to decrease it. A dedicated volume HUD shows the current level while the gesture is active.

### Gesture toggles

Settings contains independent toggles for:

- Horizontal gestures: left and right edge track navigation.
- Vertical gestures: top-edge play/pause and live volume control.

Disabling a gesture group stops its global monitoring behavior. Re-enable it from Settings when needed.

## Keyboard Shortcuts

Keyboard shortcuts are active in Ambient Mode.

| Shortcut | Action |
| --- | --- |
| `Space` | Play or pause |
| `Left Arrow` | Previous track |
| `Right Arrow` | Next track |
| `Up Arrow` | Increase volume by 10% |
| `Down Arrow` | Decrease volume by 10% |
| `L` | Show or hide live lyrics |
| `T` | Cycle Vinyl, Cassette, and Glass themes |
| `ESC` | Exit Ambient Mode |

## Settings

Open Settings from the hover panel or Option-right-click the main menu bar item.

### General

- Launch at login: start Songleton automatically when macOS starts.
- Track change notifications: enable or disable non-activating track notifications.
- Horizontal gestures: enable or disable left/right edge navigation.
- Vertical gestures: enable or disable top-edge play/pause and live volume gestures.
- Edge hold duration: configure how long the cursor must rest at an edge before an edge action triggers.

### Language

Choose System, English, or Turkish. Songleton stores the selected language and applies it to the menu, Settings, onboarding, and in-app controls.

### Menu bar

- Show artist name beside the track.
- Show or hide the previous and next menu bar buttons.
- Choose the System or Audiowide menu bar font.
- Set the menu bar track label width.

### Lyrics

Use Lyrics sync offset to compensate when lyrics appear too early or too late. Positive values move the active lyric selection forward; negative values move it backward.

### Permissions

Settings shows the current Automation and Accessibility permission state and links directly to the relevant macOS Privacy & Security page.

## Lyrics

Songleton requests lyrics from [LRCLIB](https://lrclib.net/) using the current track, artist, album, and duration. Synced LRC lyrics are preferred; plain lyrics are supported as a fallback.

To use lyrics:

1. Enter Ambient Mode.
2. Press `L` or select the lyrics control in the toolbar.
3. Wait for the lookup to complete.

Lyrics are fetched per track and cleared when playback stops or the track changes. If no result is available, the rest of Ambient Mode remains fully usable.

## Troubleshooting

### Songleton shows no track

- Confirm Spotify or Apple Music is running.
- Confirm a track is loaded or playing.
- Open Settings > Permissions and check Automation access.
- If access was recently changed, restart Songleton and the music player.

### Playback commands do not work

- Grant Automation permission for the specific player.
- Check that the player is installed using its standard application identity.
- If both players are open, verify which one is currently playing.

### Edge gestures do not work

- Grant Accessibility permission to Songleton.
- Confirm the relevant horizontal or vertical gesture toggle is enabled.
- Hold the pointer directly against the screen edge for the configured duration.
- Check that another global mouse utility is not intercepting the same events.

### Lyrics are missing or out of sync

- Check your internet connection.
- Confirm the track metadata matches the player metadata.
- Adjust Settings > Lyrics > Lyrics sync offset.
- LRCLIB may not have lyrics for every track.

### Ambient Mode does not respond to the keyboard

- Click once inside Ambient Mode to ensure it is active.
- Use `ESC` to leave and enter Ambient Mode again.
- Check that another application is not holding a global keyboard shortcut.

## Privacy

Songleton has no account system, analytics, advertising, tracking, or listening-history upload.

- Track name, artist, album, and duration are sent to LRCLIB only when requesting lyrics.
- Album artwork is read from the active media player or its artwork URL.
- Playback control is performed locally through macOS Apple Events.
- Passwords, personal files, listening history, and player credentials are not uploaded by Songleton.

See [SECURITY.md](SECURITY.md) for reporting security issues.

## Build and Development

Songleton is a native SwiftUI and AppKit application. Media integrations are isolated behind the `MediaController` protocol, with separate Spotify and Apple Music AppleScript controllers.

### Common commands

```bash
# Build and launch the Debug app
make

# Build without launching
make build-debug

# Run the native unit test runner
make test

# Run tests and build with warnings treated as errors
make quality

# Generate an LLVM coverage report
make coverage

# Clean build products and Xcode's project build outputs
make clean
```

### Release commands

Distribution requires a Developer ID identity and Apple notarization credentials. See [RELEASING.md](RELEASING.md) for the complete release process.

```bash
make archive DEVELOPER_IDENTITY="Developer ID Application: Your Name (TEAMID)"
make dmg DEVELOPER_IDENTITY="Developer ID Application: Your Name (TEAMID)"
make notarize DEVELOPER_IDENTITY="Developer ID Application: Your Name (TEAMID)" NOTARY_PROFILE="profile-name"
```

GitHub Actions runs the quality gate on pull requests and pushes to `main`.

## License

Songleton is distributed under the [MIT License](LICENSE).

The bundled Audiowide typeface is licensed under the [SIL Open Font License 1.1](https://openfontlicense.org/). See the font metadata and repository notices for attribution details.
