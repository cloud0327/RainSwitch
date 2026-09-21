import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: TrackStore
    @ObservedObject var playback: Playback

    var body: some View {
        Form {
            Section {
                ForEach(0..<5, id: \.self) { index in
                    HStack(spacing: 12) {
                        Text("Slot \(index + 1)")
                            .foregroundStyle(.secondary)
                            .frame(width: 48, alignment: .leading)
                        if let slot = store.slots[index] {
                            Text(slot.name)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .foregroundStyle(store.available[index] ? .primary : .secondary)
                                .help(slot.name)
                            Spacer(minLength: 8)
                            Button("Change…") { store.choose(slot: index) }
                            Button("Remove") { store.remove(index) }
                        } else {
                            Text("Empty").foregroundStyle(.tertiary)
                            Spacer()
                            Button("Add…") { store.choose(slot: index) }
                        }
                    }
                    .padding(.vertical, 3)
                }
            } header: {
                Text("Rain Lo-fi")
            } footer: {
                Text(store.canPlay ? "メニューバーから再生できます。" : "再生には5曲すべての登録が必要です。")
            }

            if store.isEmpty {
                Button("5ファイルを選択…") { store.choose() }
            }
            if let message = store.message ?? playback.error {
                Text(message).font(.callout).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 540)
        .fixedSize(horizontal: false, vertical: true)
        .scenePadding()
    }
}
