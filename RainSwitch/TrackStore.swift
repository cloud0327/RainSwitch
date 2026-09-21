import AppKit
import AVFoundation
import Combine
import UniformTypeIdentifiers

struct TrackSlot: Codable {
    var name: String
    var bookmark: Data
}

@MainActor
final class TrackStore: ObservableObject {
    @Published private(set) var slots: [TrackSlot?] = Array(repeating: nil, count: 5)
    @Published private(set) var available = Array(repeating: false, count: 5)
    @Published var message: String?
    let playback = Playback()
    private var scopedURLs: [URL] = []
    private let defaults: UserDefaults
    private let key = "RainSwitch.trackSlots.v1"
    var canPlay: Bool { available.allSatisfy { $0 } }
    var isEmpty: Bool { slots.allSatisfy { $0 == nil } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key),
           let saved = try? JSONDecoder().decode([TrackSlot?].self, from: data), saved.count == 5 {
            slots = saved
        }
        resolve()
    }

    deinit {
        scopedURLs.forEach { $0.stopAccessingSecurityScopedResource() }
    }

    func choose(slot: Int? = nil) {
        guard slot.map({ (0..<5).contains($0) }) ?? isEmpty else { return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.wav, .mp3, .mpeg4Audio, .audio]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = slot == nil
        let selection = SelectionOrder()
        panel.delegate = selection
        panel.prompt = slot == nil ? "5曲を登録" : "登録"
        panel.message = slot == nil ? "WAV・MP3・M4Aなどの音声ファイルを5つ選択してください。選択順にSlot 1〜5へ登録します。" : "このSlotの音声を選択してください（WAV・MP3・M4Aなど）。"
        guard panel.runModal() == .OK else { return }
        let urls = selection.ordered(panel.urls)
        guard urls.count == (slot == nil ? 5 : 1) else {
            message = "音声ファイルをちょうど5つ選択してください。"
            return
        }
        do { try register(urls, slot: slot) }
        catch { message = "音声ファイルを登録できません。\n\(error.localizedDescription)" }
    }

    func register(_ urls: [URL], slot: Int? = nil) throws {
        guard slot.map({ slots.indices.contains($0) }) ?? isEmpty,
              urls.count == (slot == nil ? 5 : 1) else {
            throw CocoaError(.validationMissingMandatoryProperty)
        }
        // Validate the entire selection before modifying the five fixed slots.
        let replacements: [TrackSlot] = try urls.map { url in
            let file = try AVAudioFile(forReading: url)
            guard file.length > 0 else { throw CocoaError(.fileReadCorruptFile) }
            return TrackSlot(name: url.lastPathComponent,
                             bookmark: try url.bookmarkData(options: [
                                .withSecurityScope,
                                .securityScopeAllowOnlyReadAccess
                             ],
                             includingResourceValuesForKeys: nil, relativeTo: nil))
        }
        playback.stop()
        if let slot { slots[slot] = replacements[0] }
        else { slots = replacements.map(Optional.some) }
        save()
        resolve()
    }

    func remove(_ slot: Int) {
        guard slots.indices.contains(slot) else { return }
        playback.stop()
        slots[slot] = nil
        save()
        resolve()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(slots) { defaults.set(data, forKey: key) }
    }

    private func resolve() {
        playback.configure([])
        scopedURLs.forEach { $0.stopAccessingSecurityScopedResource() }
        scopedURLs = []
        available = Array(repeating: false, count: 5)
        message = nil
        var resolved: [URL] = []
        for index in slots.indices {
            guard let slot = slots[index] else { continue }
            do {
                var stale = false
                let url = try URL(resolvingBookmarkData: slot.bookmark,
                                  options: [.withSecurityScope, .withoutUI], relativeTo: nil,
                                  bookmarkDataIsStale: &stale)
                if url.startAccessingSecurityScopedResource() { scopedURLs.append(url) }
                let file = try AVAudioFile(forReading: url)
                guard file.length > 0 else {
                    throw CocoaError(.fileReadCorruptFile)
                }
                if stale {
                    slots[index]?.bookmark = try url.bookmarkData(options: [
                        .withSecurityScope,
                        .securityScopeAllowOnlyReadAccess
                    ], includingResourceValuesForKeys: nil, relativeTo: nil)
                }
                resolved.append(url)
                available[index] = true
            } catch { message = "読み込めない音声があります。該当SlotのChange…で再登録してください。" }
        }
        save()
        if canPlay { playback.configure(resolved) }
    }
}

// NSOpenPanel.urls can reflect browser order. Preserve incremental selections
// so Command-clicking files assigns slots in the user's selection order.
@MainActor
private final class SelectionOrder: NSObject, NSOpenSavePanelDelegate {
    private var urls: [URL] = []

    func panelSelectionDidChange(_ sender: Any?) {
        guard let panel = sender as? NSOpenPanel else { return }
        _ = ordered(panel.urls)
    }

    func ordered(_ selected: [URL]) -> [URL] {
        urls.removeAll { !selected.contains($0) }
        for url in selected where !urls.contains(url) { urls.append(url) }
        return urls
    }
}
