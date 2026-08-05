import AVFoundation
import AppKit

@MainActor
final class TutorialAudioService {
    static let shared = AppContainer.shared.tutorialAudio

    private var player: AVAudioPlayer?
    private var preparedPlayers: [Int: AVAudioPlayer] = [:]
    private var transitionTask: Task<Void, Never>?
    private var volumeTask: Task<Void, Never>?
    private var notificationTokens: [NSObjectProtocol] = []
    private var sessionIsActive = false
    private var wasPlayingBeforeInterruption = false
    private var sessionGeneration = 0
    private(set) var currentTrack: Int?
    private(set) var targetVolume: Float = 0.08

    init() {
        let appCenter = NotificationCenter.default
        notificationTokens.append(appCenter.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleInterruption()
            }
        })
        notificationTokens.append(appCenter.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.resumeAfterInterruption()
            }
        })

        let workspaceCenter = NSWorkspace.shared.notificationCenter
        notificationTokens.append(workspaceCenter.addObserver(
            forName: NSWorkspace.screensDidSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleInterruption()
            }
        })
        notificationTokens.append(workspaceCenter.addObserver(
            forName: NSWorkspace.screensDidWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.resumeAfterInterruption()
            }
        })
    }

    func beginSession() {
        sessionGeneration += 1
        sessionIsActive = true
        wasPlayingBeforeInterruption = false
        preparePlayers()
        start()
    }

    func start() {
        if currentTrack == 1, player?.isPlaying == true {
            return
        }
        targetVolume = 0.08
        play(track: 1, fadeIn: true)
    }

    func switchToSecondTrack() {
        guard currentTrack != 2 else {
            resume(fadeIn: true)
            return
        }
        play(track: 2, fadeIn: true)
    }

    func pause() {
        player?.pause()
    }

    func resume(fadeIn: Bool = false) {
        guard let player else { return }
        if fadeIn {
            player.volume = 0
        }
        player.play()
        if fadeIn {
            fade(player, from: 0, to: targetVolume, duration: 0.7)
        }
    }

    func setDemoVolume(_ volume: Int) {
        let clamped = Float(min(max(volume, 0), 20)) / 100
        targetVolume = clamped
        volumeTask?.cancel()
        player?.setVolume(clamped, fadeDuration: 0.05)
    }

    func stop() {
        sessionGeneration += 1
        sessionIsActive = false
        wasPlayingBeforeInterruption = false
        transitionTask?.cancel()
        volumeTask?.cancel()
        let cachedPlayers = Array(preparedPlayers.values)
        preparedPlayers.removeAll()
        guard let player else {
            currentTrack = nil
            cachedPlayers.forEach { $0.stop() }
            return
        }

        let startingVolume = player.volume
        self.player = nil
        currentTrack = nil
        let generation = sessionGeneration
        volumeTask = Task { @MainActor [weak self, player] in
            await self?.animateVolume(on: player, from: startingVolume, to: 0, duration: 0.45)
            guard !Task.isCancelled, self?.sessionGeneration == generation else { return }
            player.stop()
            cachedPlayers.filter { $0 !== player }.forEach { $0.stop() }
        }
    }

    private func preparePlayers() {
        for track in [1, 2] where preparedPlayers[track] == nil {
            guard let url = Bundle.main.url(forResource: String(track), withExtension: "mp3") else {
                assertionFailure("Missing tutorial audio resource: \(track).mp3")
                continue
            }
            do {
                let prepared = try AVAudioPlayer(contentsOf: url)
                prepared.numberOfLoops = -1
                prepared.volume = 0
                prepared.prepareToPlay()
                preparedPlayers[track] = prepared
            } catch {
                assertionFailure("Could not preload tutorial audio: \(error.localizedDescription)")
            }
        }
    }

    private func handleInterruption() {
        guard sessionIsActive, let player else { return }
        wasPlayingBeforeInterruption = player.isPlaying
        if player.isPlaying {
            player.pause()
        }
    }

    private func resumeAfterInterruption() {
        guard sessionIsActive, wasPlayingBeforeInterruption else { return }
        wasPlayingBeforeInterruption = false
        resume(fadeIn: true)
    }

    private func play(track: Int, fadeIn: Bool) {
        guard let url = Bundle.main.url(forResource: String(track), withExtension: "mp3") else {
            assertionFailure("Missing tutorial audio resource: \(track).mp3")
            return
        }

        transitionTask?.cancel()
        volumeTask?.cancel()
        let oldPlayer = player
        let oldVolume = oldPlayer?.volume ?? 0

        do {
            let newPlayer: AVAudioPlayer
            if let prepared = preparedPlayers[track] {
                newPlayer = prepared
                newPlayer.currentTime = 0
            } else {
                newPlayer = try AVAudioPlayer(contentsOf: url)
                preparedPlayers[track] = newPlayer
            }
            newPlayer.numberOfLoops = -1
            newPlayer.volume = fadeIn ? 0 : targetVolume
            newPlayer.prepareToPlay()
            newPlayer.play()

            player = newPlayer
            currentTrack = track

            let targetVolume = self.targetVolume
            let generation = sessionGeneration
            transitionTask = Task { @MainActor [weak self, oldPlayer, newPlayer] in
                await self?.animateCrossfade(
                    from: oldPlayer,
                    oldVolume: oldVolume,
                    to: newPlayer,
                    newVolume: targetVolume,
                    duration: fadeIn ? 1.35 : 0.5
                )
                guard !Task.isCancelled, self?.sessionGeneration == generation else { return }
                oldPlayer?.stop()
            }
        } catch {
            assertionFailure("Could not load tutorial audio: \(error.localizedDescription)")
        }
    }

    private func fade(_ player: AVAudioPlayer, from: Float, to: Float, duration: Double) {
        volumeTask?.cancel()
        let generation = sessionGeneration
        volumeTask = Task { @MainActor [weak self, weak player] in
            await self?.animateVolume(on: player, from: from, to: to, duration: duration)
            guard !Task.isCancelled, self?.sessionGeneration == generation else { return }
        }
    }

    private func animateVolume(
        on player: AVAudioPlayer?,
        from start: Float,
        to end: Float,
        duration: Double
    ) async {
        guard let player else { return }
        let frameCount = max(1, Int(duration * 60))
        for frame in 0...frameCount {
            guard !Task.isCancelled else { return }
            let progress = Float(frame) / Float(frameCount)
            let eased = progress * progress * (3 - 2 * progress)
            player.volume = start + (end - start) * eased
            try? await Task.sleep(for: .milliseconds(16))
        }
    }

    private func animateCrossfade(
        from oldPlayer: AVAudioPlayer?,
        oldVolume: Float,
        to newPlayer: AVAudioPlayer,
        newVolume: Float,
        duration: Double
    ) async {
        let frameCount = max(1, Int(duration * 60))
        for frame in 0...frameCount {
            guard !Task.isCancelled else { return }
            let progress = Float(frame) / Float(frameCount)
            let eased = progress * progress * (3 - 2 * progress)
            oldPlayer?.volume = oldVolume * (1 - eased)
            newPlayer.volume = newVolume * eased
            try? await Task.sleep(for: .milliseconds(16))
        }
    }
}
