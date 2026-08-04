# Contributing guide

Run `make quality` before every change. When adding new behavior, add a deterministic test to the local test runner under `SongletonTests` when possible.

Code that touches system-level features, AppleScript, permission dialogs, and the global mouse event tap, requires manual testing with real apps. Tests cannot replace that. For visual changes, verify against both Spotify and Apple Music in both playing and paused states.

Keep commits focused on a single behavioral change. Build outputs, `.xcarchive`, DMGs, and personal Xcode settings never enter the repository.
