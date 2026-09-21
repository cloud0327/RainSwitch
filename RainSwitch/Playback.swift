import AVFoundation
import Combine

@MainActor
final class Playback: ObservableObject {
    @Published private(set) var isPlaying = false
    @Published private(set) var error: String?
    private(set) var currentSlot = 0
    var position: TimeInterval { current?.currentTime ?? 0 }
    var nextPosition: TimeInterval { next?.currentTime ?? 0 }
    var isCrossfading: Bool { nextHasStarted }
    private var urls: [URL] = []
    private var current: AVAudioPlayer?
    private var next: AVAudioPlayer?
    private var fade: Crossfade?
    private var timer: Timer?
    private var activity: NSObjectProtocol?
    private var nextHasStarted = false
    private var nextStartTime: TimeInterval = 0

    func configure(_ urls: [URL]) {
        stop()
        self.urls = urls.count == 5 ? urls : []
        error = nil
    }

    func toggle() {
        if isPlaying { pause() } else { resume() }
    }

    func restart() {
        stop()
        resume()
    }

    func stop() {
        endActivity()
        timer?.invalidate()
        timer = nil
        current?.stop()
        next?.stop()
        current = nil
        next = nil
        fade = nil
        currentSlot = 0
        nextHasStarted = false
        isPlaying = false
    }

    func pause() {
        guard isPlaying else { return }
        tick()
        guard isPlaying, let current, let next else { return }
        // Cancel a future scheduled start as well as pausing both audible voices.
        current.pause()
        if nextHasStarted {
            next.pause()
        } else {
            next.stop()
            next.currentTime = 0
            next.prepareToPlay()
        }
        timer?.invalidate()
        timer = nil
        isPlaying = false
        endActivity()
    }

    private func makePlayer(_ slot: Int) throws -> AVAudioPlayer {
        let player = try AVAudioPlayer(contentsOf: urls[slot])
        guard player.duration.isFinite, player.duration > 0, player.prepareToPlay() else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return player
    }

    private func resume() {
        guard urls.count == 5, !isPlaying else { return }
        do {
            if current == nil {
                currentSlot = 0
                current = try makePlayer(0)
                next = try makePlayer(1)
                fade = Crossfade(currentDuration: current!.duration, nextDuration: next!.duration)
                nextHasStarted = false
            }
            guard let current, let next, let fade else { return }
            let gains = fade.gains(at: current.currentTime)
            current.volume = gains.current
            next.volume = gains.next
            // Both players use the audio device clock, including resume mid-fade.
            let startTime = current.deviceCurrentTime + 0.04
            guard current.play(atTime: startTime) else { throw CocoaError(.fileReadUnknown) }
            nextStartTime = startTime + (nextHasStarted ? 0 : max(0, fade.start - current.currentTime))
            guard next.play(atTime: nextStartTime) else { throw CocoaError(.fileReadUnknown) }
            error = nil
            isPlaying = true
            activity = ProcessInfo.processInfo.beginActivity(
                options: .userInitiatedAllowingIdleSystemSleep,
                reason: "Rain Lo-fi playback"
            )
            let timer = Timer(timeInterval: 1 / 120, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.tick() }
            }
            self.timer = timer
            RunLoop.main.add(timer, forMode: .common)
        } catch {
            fail(error)
        }
    }

    private func tick() {
        guard isPlaying, let current, let next, let fade else { return }
        if current.deviceCurrentTime >= nextStartTime { nextHasStarted = true }
        // AVAudioPlayer resets currentTime when reaching EOF; use the incoming
        // player's progress to recognize the transition even after that reset.
        if nextHasStarted && next.currentTime >= fade.duration {
            current.stop()
            next.volume = 1
            self.current = next
            self.next = nil
            currentSlot = Crossfade.successor(of: currentSlot)
            do {
                let upcoming = try makePlayer(Crossfade.successor(of: currentSlot))
                let newFade = Crossfade(currentDuration: next.duration, nextDuration: upcoming.duration)
                self.next = upcoming
                self.fade = newFade
                nextHasStarted = false
                upcoming.volume = 0
                nextStartTime = next.deviceCurrentTime + max(0, newFade.start - next.currentTime)
                guard upcoming.play(atTime: nextStartTime) else { throw CocoaError(.fileReadUnknown) }
            } catch { fail(error) }
        } else {
            let progress = nextHasStarted ? fade.start + next.currentTime : current.currentTime
            let gains = fade.gains(at: progress)
            current.volume = gains.current
            next.volume = gains.next
        }
    }

    private func fail(_ cause: Error) {
        stop()
        error = "音声を再生できません。Settingsでファイルを再登録してください。\n\(cause.localizedDescription)"
    }

    private func endActivity() {
        if let activity { ProcessInfo.processInfo.endActivity(activity) }
        activity = nil
    }
}
