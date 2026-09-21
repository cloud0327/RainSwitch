import AVFoundation
import XCTest
@testable import RainSwitchCore

final class PlaybackTests: XCTestCase {
    @MainActor
    func testPauseResumeRestartAndFiveToOneWithRealPlayers() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 88200)!
        buffer.frameLength = 88200
        memset(buffer.floatChannelData![0], 0, Int(buffer.frameLength) * MemoryLayout<Float>.size)
        let urls = try (0..<5).map { index in
            let url = directory.appendingPathComponent("\(index).wav")
            let file = try AVAudioFile(forWriting: url, settings: format.settings)
            try file.write(from: buffer)
            return url
        }
        let player = Playback()
        defer { player.stop() }
        player.configure(urls)
        player.toggle()
        XCTAssertTrue(player.isPlaying, player.error ?? "")
        try await Task.sleep(for: .milliseconds(1400))
        XCTAssertTrue(player.isCrossfading)
        player.pause()
        let currentPosition = player.position
        let nextPosition = player.nextPosition
        XCTAssertGreaterThan(nextPosition, 0.1)
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertEqual(player.position, currentPosition, accuracy: 0.02)
        XCTAssertEqual(player.nextPosition, nextPosition, accuracy: 0.02)
        player.toggle()
        try await Task.sleep(for: .milliseconds(250))
        XCTAssertGreaterThan(player.position, currentPosition + 0.1)
        XCTAssertGreaterThan(player.nextPosition, nextPosition + 0.1)
        player.restart()
        XCTAssertEqual(player.currentSlot, 0)
        XCTAssertLessThan(player.position, 0.1)
        XCTAssertLessThan(player.nextPosition, 0.1)
        XCTAssertFalse(player.isCrossfading)
        player.pause()
        let restartedPosition = player.position
        // Wait past the canceled next-track deadline while paused.
        try await Task.sleep(for: .milliseconds(1250))
        XCTAssertEqual(player.position, restartedPosition, accuracy: 0.02)
        XCTAssertEqual(player.nextPosition, 0, accuracy: 0.02)
        player.toggle()
        var seen: [Int] = [0]
        for _ in 0..<140 {
            try await Task.sleep(for: .milliseconds(50))
            if seen.last != player.currentSlot { seen.append(player.currentSlot) }
            if seen.count == 6 { break }
        }
        XCTAssertEqual(seen, [0, 1, 2, 3, 4, 0])
        XCTAssertTrue(player.isPlaying)
        player.configure(Array(urls.prefix(4)))
        XCTAssertFalse(player.isPlaying)
        player.toggle()
        XCTAssertFalse(player.isPlaying)
    }
}
