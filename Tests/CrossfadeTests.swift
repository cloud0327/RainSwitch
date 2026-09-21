import XCTest
@testable import RainSwitchCore

final class CrossfadeTests: XCTestCase {
    func testEqualPowerAcrossWholeFade() {
        let fade = Crossfade(currentDuration: 60, nextDuration: 90)
        XCTAssertEqual(fade.start, 54)
        XCTAssertEqual(fade.duration, 6)
        for step in 0...600 {
            let gains = fade.gains(at: 54 + Double(step) / 100)
            XCTAssertEqual(gains.current * gains.current + gains.next * gains.next, 1, accuracy: 0.00001)
        }
        XCTAssertEqual(fade.gains(at: 0).current, 1)
        XCTAssertEqual(fade.gains(at: 0).next, 0)
        XCTAssertEqual(fade.gains(at: 60).current, 0, accuracy: 0.00001)
        XCTAssertEqual(fade.gains(at: 60).next, 1)
    }

    func testShortTracksNeverNeedThreeSimultaneousPlayers() {
        let durations: [Double] = [1, 3, 40, 0.2, 8]
        for index in 0..<5 {
            let previous = durations[(index + 4) % 5]
            let current = durations[index]
            let next = durations[(index + 1) % 5]
            let incoming = Crossfade(currentDuration: previous, nextDuration: current)
            let outgoing = Crossfade(currentDuration: current, nextDuration: next)
            XCTAssertLessThanOrEqual(incoming.duration + outgoing.duration, current)
        }
    }

    func testFixedOrderWrapsForever() {
        var slot = 0
        for index in 0..<1000 {
            XCTAssertEqual(slot, index % 5)
            slot = Crossfade.successor(of: slot)
        }
    }

    @MainActor func testFreshStoreHasFiveEmptySlotsAndCannotPlay() {
        let name = "RainSwitchTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let store = TrackStore(defaults: defaults)
        XCTAssertEqual(store.slots.count, 5)
        XCTAssertTrue(store.isEmpty)
        XCTAssertFalse(store.canPlay)
        store.playback.toggle()
        XCTAssertFalse(store.playback.isPlaying)
        store.playback.restart()
        XCTAssertFalse(store.playback.isPlaying)
    }
}
