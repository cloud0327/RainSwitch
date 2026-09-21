import Foundation

struct Crossfade {
    let duration: TimeInterval
    let start: TimeInterval

    init(currentDuration: TimeInterval, nextDuration: TimeInterval) {
        duration = min(6, currentDuration / 2, nextDuration / 2)
        start = currentDuration - duration
    }

    func gains(at position: TimeInterval) -> (current: Float, next: Float) {
        let progress = min(1, max(0, (position - start) / duration))
        return (Float(cos(progress * .pi / 2)), Float(sin(progress * .pi / 2)))
    }

    static func successor(of slot: Int) -> Int { (slot + 1) % 5 }
}
