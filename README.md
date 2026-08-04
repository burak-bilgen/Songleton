# Songleton

## Your music, one move away.

Songleton is the native macOS companion for Spotify and Apple Music. It keeps the track you are listening to in the menu bar, turns the edges of your screen into deliberate controls, and gives music a focused home when you want one.

No separate music library. No account layer. No floating player that competes with your work. Songleton controls the app you already use and disappears when there is nothing to control.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-111827?style=for-the-badge&logo=apple&logoColor=white)
![Swift](https://img.shields.io/badge/Swift-5-orange?style=for-the-badge&logo=swift&logoColor=white)
![SwiftUI](https://img.shields.io/badge/SwiftUI-Native-6D5DFB?style=for-the-badge&logo=swift&logoColor=white)
![License](https://img.shields.io/badge/license-MIT-38BDF8?style=for-the-badge)

## Why Songleton exists

Music controls should be near, not noisy. Songleton puts the song title, previous, next, and play or pause controls in the menu bar. Hover once for the full controller. Hold the cursor at an edge when you need to move fast. Open Ambient Mode when the music deserves the screen.

It is designed for people who work, write, code, design, or browse with music on all day and do not want to keep switching back to the player.

## What you get

| Surface | What it does |
| --- | --- |
| Menu bar | Shows the current track only while Spotify or Apple Music has usable playback. Previous, next, and title controls remain one click away. |
| Hover panel | Artwork, playback, shuffle, repeat, mute, volume, settings, Ambient Mode, and Spotify discovery in one compact panel. |
| Screen gestures | Previous, next, play or pause, and volume without finding a button. Clear visual feedback prevents accidental triggers. |
| New-track HUD | A non-activating track notification that enters from the selected screen edge, keeps its glow intact, and never steals focus. |
| Ambient Mode | A full-screen music scene with Vinyl, Cassette, and Glass themes, lyrics, seek, sleep timer, and keyboard controls. |
| Guided setup | Human onboarding, permission recovery, and a synchronized visual tutorial before controls become active. |

## Menu bar, without menu bar nonsense

Songleton reveals itself only when a supported player has a track ready. When Spotify and Apple Music are both idle, the menu bar stays clean and gesture monitoring is inactive.

| Action | Result |
| --- | --- |
| Left-click the track title | Play or pause |
| Hover the track title | Open the full control panel |
| Right-click the track title | Enter Ambient Mode |
| Option-right-click the track title | Open Settings, onboarding, or Quit |
| Previous / next buttons | Move through the queue |

The three status items intentionally use a non-obvious AppKit initialization order. Do not reorder their creation or visibility calls without testing on a real macOS menu bar. AppKit is being AppKit.

## The hover panel

Hover the song title and Songleton expands into a compact control room:

- Live artwork, title, artist, and player-aware color.
- Previous, next, play or pause, shuffle, repeat, mute, and volume.
- Tooltips and VoiceOver labels for every actionable control.
- Ambient Mode, Settings, and Quit without a separate window.
- Spotify picks at the bottom whenever Spotify is the active player.

### Spotify picks

When Spotify is active, the hover panel offers five compact one-click playlists. The catalog contains only verified Spotify editorial playlists, never community copies that happen to share a chart name. Select a playlist and Songleton tells the already-running Spotify desktop app to enable shuffle and begin that playlist without opening a browser or intentionally bringing Spotify to the front.

This does not require a Songleton account, Spotify OAuth flow, IP geolocation, or a hidden web scraper. The Spotify app itself still needs to be installed, running, authorized for Automation, and signed in as usual. The catalog is intentionally curated rather than advertised as a live Spotify ranking feed.

## Screen-edge gestures

Songleton makes quick controls spatial. Hold the pointer at an edge long enough to commit, then get out of the way.

| Gesture | Result |
| --- | --- |
| Hold at the left screen edge | Previous track |
| Hold at the right screen edge | Next track |
| Hold at the top screen edge | Play or pause |
| Hold both mouse buttons and drag vertically | Change volume |
| Hold Command + Option and drag vertically | Change volume |

The default hold duration is `0.65s`. Top-edge play or pause intentionally resolves a little faster. Leave the edge before the ring fills and the action cancels. Gesture groups can be disabled independently in Settings, which also stops their monitoring work.

Global gestures require Accessibility permission, an available supported player, and an explicitly completed or skipped tutorial. Closing the tutorial does not silently unlock controls.

## New-track HUD

Songleton can greet a track change without interrupting the app in front of you.

- It is a non-activating panel. Your keyboard focus stays where it was.
- It appears on the display under the pointer.
- Choose any of eight useful placements: three across the top, left and right center, or three across the bottom.
- Each placement enters and exits through its nearest screen edge. Corner placements never take a weird diagonal route.
- The notification card stays close to the chosen edge while its transparent panel gives the outer glow enough room to breathe.
- Long titles expand and wrap within the available display width instead of being chopped into a useless ellipsis.
- Settings includes a clear placement selector, an appearance sample, and a full-screen preview button.

## Ambient Mode

Ambient Mode opens on the display under the pointer. It hides the Dock and menu bar while active, then restores the desktop when you leave. It is not a fake visualizer bolted onto the app. It is the same player state, controls, volume, artwork, and lyrics in a calmer place.

Choose the mood:

| Theme | Character |
| --- | --- |
| Vinyl | Artwork-led record scene |
| Cassette | Mechanical retro texture |
| Glass | Minimal color and cover art |

While Ambient Mode is focused:

| Shortcut | Result |
| --- | --- |
| Space | Play or pause |
| Left / Right Arrow | Previous / next |
| Up / Down Arrow | Change volume |
| L | Show or hide synced lyrics |
| T | Cycle visual theme |
| Esc | Exit Ambient Mode |

The interface fades when idle and comes back when you move the pointer. Reduce Motion is respected, so continuous movement and the CRT exit are softened or skipped when macOS asks for less animation.

## Onboarding and tutorial

First launch is intentionally not a permission ambush. Songleton explains what it does, shows the menu bar behavior, and asks only for the permissions each feature needs.

If setup closes before permissions are granted, Songleton opens a focused recovery window on the next launch instead of pretending the app is ready. Until setup and the tutorial are resolved, controls and gestures stay off.

The interactive tutorial demonstrates the complete flow with its own deterministic music data:

1. Cancel an edge gesture by leaving the edge.
2. Hold the right edge to skip to the next track.
3. Hold the top edge to pause, watch the gesture finish, then resume.
4. Change volume with mouse or keyboard-assisted drag.
5. Hover the menu bar title to reveal the control panel.
6. Right-click the title to enter Ambient Mode.

Its soundtrack begins only after the tutorial begins, crossfades at the visible track-change moment, pauses for the pause demo, resumes after the gesture resolves, and follows the volume demo at a restrained level. The demo works even when no real player is open.

## Lyrics, language, and accessibility

- Synced LRC lyrics when available, plain lyrics as a fallback.
- Adjustable lyric timing offset.
- Turkish, English, or macOS system language.
- VoiceOver labels, tooltips, visible focus states, and Reduce Motion support.
- UI previews never depend on a real song, so Settings and tutorial states remain understandable.

## Privacy

Songleton is deliberately local-first.

- Playback control uses macOS Apple Events with your permission.
- Songleton does not ask you to create an account.
- It has no analytics, advertising, tracking, or listening-history upload.
- Artwork comes from the active player or its artwork URL.
- Lyrics are fetched from [LRCLIB](https://lrclib.net/) using only the current track, artist, album, and duration needed for lookup.
- Spotify picks use a small built-in editorial catalog. Songleton does not use physical location, IP geolocation, or a hidden Spotify web scraper.
- Passwords, player credentials, local files, and listening history are never uploaded.

## Requirements

- macOS 14 or newer.
- Spotify and/or Apple Music installed.
- Automation permission for every player Songleton should control.
- Accessibility permission for global gestures.
- Internet access only when lyrics need to be fetched from LRCLIB.

## Website and releases

The animated product site lives in [`docs/index.html`](docs/index.html). It is a dependency-free static page built for GitHub Pages, so there is no separate hosting account, framework deployment, or domain to manage.

After pushing this repository, enable **Settings > Pages > Build and deployment > Source: GitHub Actions** once. The included workflow deploys every change to `main` that touches `docs/`, and GitHub serves the site at `https://burak-bilgen.github.io/Songleton/`.

The release path is deliberately strict:

```bash
# Build, sign, notarize, and package the DMG with the release credentials.
make notarize

# Replace the staged checksum in the Homebrew cask with the actual DMG checksum.
./scripts/update-homebrew-cask.sh build/Songleton-1.0.dmg
```

Then commit the generated checksum, create the matching `v1.0` GitHub Release, and attach `Songleton-1.0.dmg`. The cask at [`homebrew-tap/Casks/songleton.rb`](homebrew-tap/Casks/songleton.rb) intentionally starts with `sha256 :no_check`; it is a release staging file, not a claim that an unsigned artifact is ready to install. The exact Homebrew steps are in [`homebrew-tap/README.md`](homebrew-tap/README.md).

## Build from source

```bash
git clone https://github.com/burak-bilgen/Songleton.git
cd Songleton
make
```

`make` builds the Debug app and launches it. Songleton is a menu bar app, so there is no conventional main window waiting to greet you.

Useful development commands:

```bash
# Build and launch
make

# Build without launching
make build-debug

# Run the native test runner
make test

# Test and reject compiler warnings
make quality

# Clear build products
make clean

# Reset local defaults, caches, and Songleton Automation permission
make fresh
```

The native test suite covers settings persistence, notification layout and motion, Spotify editorial catalog integrity, player resolution, lyrics parsing, localization behavior, tutorial gating, and the pure screen-edge gesture contract.

## License

Songleton is distributed under the [MIT License](LICENSE). The bundled Audiowide typeface is available under the [SIL Open Font License 1.1](https://openfontlicense.org/).
