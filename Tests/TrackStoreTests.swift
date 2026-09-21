import AVFoundation
import XCTest
@testable import RainSwitchCore

final class TrackStoreTests: XCTestCase {
    @MainActor
    func testCommonWAVEncodingsCanBeRegisteredAndPlayed() throws {
        let name = "RainSwitchWAVTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            defaults.removePersistentDomain(forName: name)
            try? FileManager.default.removeItem(at: directory)
        }
        let variants: [(bits: Int, floating: Bool, rate: Double, channels: UInt32)] = [
            (16, false, 44100, 1), (16, false, 48000, 2),
            (24, false, 44100, 2), (24, false, 48000, 2),
            (32, true, 48000, 2)
        ]
        let urls = try variants.enumerated().map { index, variant in
            let url = directory.appendingPathComponent("sample-\(index).\(index == 4 ? "WAV" : "wav")")
            let format = AVAudioFormat(standardFormatWithSampleRate: variant.rate, channels: variant.channels)!
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(variant.rate))!
            buffer.frameLength = buffer.frameCapacity
            for channel in 0..<Int(variant.channels) {
                memset(buffer.floatChannelData![channel], 0, Int(buffer.frameLength) * MemoryLayout<Float>.size)
            }
            let settings: [String: Any] = [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: variant.rate,
                AVNumberOfChannelsKey: variant.channels,
                AVLinearPCMBitDepthKey: variant.bits,
                AVLinearPCMIsFloatKey: variant.floating,
                AVLinearPCMIsBigEndianKey: false
            ]
            let file = try AVAudioFile(forWriting: url, settings: settings)
            try file.write(from: buffer)
            return url
        }
        let store = TrackStore(defaults: defaults)
        try store.register(urls)
        XCTAssertTrue(store.canPlay)
        for url in urls {
            let player = try AVAudioPlayer(contentsOf: url)
            XCTAssertEqual(player.duration, 1, accuracy: 0.01)
            XCTAssertTrue(player.prepareToPlay(), url.lastPathComponent)
            XCTAssertTrue(player.play(), url.lastPathComponent)
            player.stop()
        }
        let restored = TrackStore(defaults: defaults)
        XCTAssertTrue(restored.canPlay)
    }

    @MainActor
    func testRegistrationReplacementRemovalAndBookmarkRestoration() throws {
        let name = "RainSwitchTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            defaults.removePersistentDomain(forName: name)
            try? FileManager.default.removeItem(at: directory)
        }
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 44100)!
        buffer.frameLength = 44100
        memset(buffer.floatChannelData![0], 0, Int(buffer.frameLength) * MemoryLayout<Float>.size)
        let urls = try (0..<6).map { index in
            let url = directory.appendingPathComponent("\(index).wav")
            let file = try AVAudioFile(forWriting: url, settings: format.settings)
            try file.write(from: buffer)
            return url
        }
        let store = TrackStore(defaults: defaults)
        XCTAssertThrowsError(try store.register(urls))
        XCTAssertTrue(store.isEmpty)
        let ordered = Array(urls.prefix(5).reversed())
        try store.register(ordered)
        XCTAssertEqual(store.slots.compactMap { $0?.name }, ordered.map(\.lastPathComponent))
        XCTAssertTrue(store.canPlay)
        XCTAssertThrowsError(try store.register([urls[5]]))
        XCTAssertThrowsError(try store.register([urls[5]], slot: 5))
        XCTAssertEqual(store.slots.count, 5)
        try store.register([urls[5]], slot: 2)
        XCTAssertEqual(store.slots[2]?.name, "5.wav")
        XCTAssertTrue(store.canPlay)
        let restored = TrackStore(defaults: defaults)
        XCTAssertEqual(restored.slots.compactMap { $0?.name }, store.slots.compactMap { $0?.name })
        XCTAssertTrue(restored.canPlay)
        store.playback.toggle()
        XCTAssertTrue(store.playback.isPlaying)
        store.remove(2)
        XCTAssertFalse(store.playback.isPlaying)
        XCTAssertNil(store.slots[2])
        XCTAssertFalse(store.canPlay)
        XCTAssertEqual(store.slots.count, 5)
        try store.register([urls[0]], slot: 2)
        XCTAssertTrue(store.canPlay)
        let invalid = directory.appendingPathComponent("invalid.wav")
        try Data("not audio".utf8).write(to: invalid)
        XCTAssertThrowsError(try store.register([invalid], slot: 2))
        XCTAssertEqual(store.slots[2]?.name, "0.wav")
        XCTAssertTrue(store.canPlay)
    }
}
