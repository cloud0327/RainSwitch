import SwiftUI
import AppKit

@main
struct RainSwitchApp: App {
    @StateObject private var store = TrackStore()
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra {
            PlayerPopover(store: store, playback: store.playback)
        } label: {
            StatusIcon(store: store, playback: store.playback, delegate: delegate)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(store: store, playback: store.playback)
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                SettingsLink { Text("Settings…") }
                    .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var openSettings: (() -> Void)?
    private var monitor: Any?
    private var sleepObserver: NSObjectProtocol?
    private var installed = false

    func install(store: TrackStore, action: @escaping () -> Void) {
        openSettings = action
        guard !installed else { return }
        installed = true
        // MenuBarExtra windows do not always route the app's menu commands.
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
               event.charactersIgnoringModifiers == "," {
                MainActor.assumeIsolated { self?.openSettings?() }
                return nil
            }
            return event
        }
        sleepObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification, object: nil, queue: .main
        ) { [weak store] _ in
            MainActor.assumeIsolated { store?.playback.pause() }
        }
        if store.isEmpty {
            DispatchQueue.main.async { action() }
        }
    }
}

private struct StatusIcon: View {
    @ObservedObject var store: TrackStore
    @ObservedObject var playback: Playback
    let delegate: AppDelegate
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Image(systemName: playback.isPlaying ? "play.fill" : "pause.fill")
            .accessibilityLabel(playback.isPlaying ? "Rain Switch：再生中" : "Rain Switch：一時停止中")
            .onAppear {
                delegate.install(store: store) {
                    NSApp.activate(ignoringOtherApps: true)
                    openSettings()
                }
            }
    }
}

private struct PlayerPopover: View {
    @ObservedObject var store: TrackStore
    @ObservedObject var playback: Playback
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        HStack(spacing: 18) {
            Button(action: playback.restart) {
                Image(systemName: "arrow.counterclockwise")
                    .frame(width: 24, height: 24)
            }
            .accessibilityLabel("Restart")
            .disabled(!store.canPlay)
            Button(action: playback.toggle) {
                Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill")
                    .frame(width: 24, height: 24)
            }
            .accessibilityLabel(playback.isPlaying ? "Pause" : "Play")
            .disabled(!store.canPlay)

            Menu {
                Button("設定…") {
                    NSApp.activate(ignoringOtherApps: true)
                    openSettings()
                }
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 24, height: 24)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .accessibilityLabel("その他の操作")
        }
        .font(.system(size: 19, weight: .regular))
        .buttonStyle(.borderless)
        .frame(width: 176, height: 92)
        .background(.regularMaterial)
    }
}
