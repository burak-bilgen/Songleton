import AppKit

/// Composition root for the application's long-lived services.
///
/// Every singleton the app reaches for through `.shared` is created here, in
/// one explicit dependency order, so construction and startup are deterministic
/// and there is a single place to reason about the service graph. Views and
/// AppKit controllers keep using the familiar `.shared` accessors; the
/// container simply owns those instances.
@MainActor
final class AppContainer {
    static let shared = AppContainer()

    let localization: LocalizationManager
    let settings: SettingsModel
    let nowPlaying: NowPlayingModel
    let lyricsModel: LyricsModel
    let mouseGestures: MouseGestureManager
    let menuBar: MenuBarManager
    let hudToasts: HUDToastManager
    let ambient: AmbientModeManager
    let tutorial: GestureTutorialManager

    let lyricsService: LyricsService
    let tutorialAudio: TutorialAudioService

    private init() {
        // Declaration order is the dependency order. NowPlayingModel observes
        // SettingsModel from its constructor, so settings must exist first.
        localization = LocalizationManager()
        settings = SettingsModel()
        nowPlaying = NowPlayingModel(settings: settings)
        lyricsService = LyricsService()
        lyricsModel = LyricsModel()
        mouseGestures = MouseGestureManager()
        menuBar = MenuBarManager()
        hudToasts = HUDToastManager()
        ambient = AmbientModeManager()
        tutorial = GestureTutorialManager()
        tutorialAudio = TutorialAudioService()
    }

    /// Starts everything that must be alive right after launch.
    func bootstrap() {
        menuBar.setup()
        nowPlaying.checkAutomationPermission()
        settings.wireGestureDependencies()
    }

    /// Stops monitoring and tears down transient state. Called on quit.
    func shutdown() {
        mouseGestures.stop()
        tutorialAudio.stop()
    }
}