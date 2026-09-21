# Rain Switch

macOS 14以降向けの、5曲固定のメニューバーBGMスイッチ。SwiftUI / MenuBarExtra / Settings / AVFoundationのみを使用します。外部ライブラリ・ネットワーク通信はありません。

## 起動

`RainSwitch.xcodeproj` をXcodeで開き、RainSwitch Schemeを実行します。ローカル実行用の署名でビルドできます。

ターミナルからビルドする場合：

```sh
xcodebuild -project RainSwitch.xcodeproj -scheme RainSwitch -configuration Release -derivedDataPath build build
open 'build/Build/Products/Release/Rain Switch.app'
```

## 使い方

1. 初回は空のSettingsが開きます。「5ファイルを選択…」から手持ちの音声を5つ選択します。個別のAdd…も使用できます。
2. Commandクリックによる選択順を記録し、Slot 1〜5に登録します。同時に範囲選択したファイル同士はmacOSが返す順序になります。
3. メニューバーのアイコンをクリックし、▶︎で再生します。メニューバーは再生中に▶︎、一時停止中にⅡを表示します。Popoverは176×92ptで、Restart、Play/Pause、横並びの「•••」メニューを表示します。
4. Pauseで両方の音声をその位置に止め、Playで再開します。RestartはSlot 1の先頭から再生します。
5. Settingsを再び開くには、Popoverの「•••」から「設定…」を選びます。音声未登録でも使用できます。Popoverを開いた状態で **⌘,** を押しても開けます。通常のメインウィンドウとDockアイコンはありません。
6. SettingsのChange…で直接置換、RemoveでそのSlotだけを空にできます。変更・削除すると再生は停止し、5曲が揃うまで再生操作が無効になります。

音声ファイルは同梱していません。mp3 / m4a / wavなど、AVFoundationで読み取れる音声を登録してください。外部ファイルのSecurity-Scoped Bookmarkを保存し、起動時に復元・古いBookmarkの更新を行います。ファイルが削除された場合などはSettingsで再登録します。

## 再生の実装

2つのAVAudioPlayerを使用し、次曲は事前に準備して音声デバイスの時刻で開始予約します。フェードの進捗は実際の再生位置から計算し、sin/cosのequal-powerカーブを120Hzで反映します。1→2→3→4→5→1すべてで同じ処理を使います。

フェードは常時6秒です。12秒未満の短い音声を含む境界のみ、`min(6, 現在曲の長さ / 2, 次曲の長さ / 2)` に短縮し、同時再生を最大2曲に保ちます。Pause時には未開始の次曲の予約も取り消し、再開時に残り時間から予約し直します。Macのスリープ時には一時停止します。

## 検証

```sh
swift test
```

テストは音声デバイスにアクセスできる通常のmacOS環境で実行してください。再生テストには生成した無音WAVを使用します。

- equal-powerのエネルギー、6秒の境界、短い音声での重複上限
- 固定順と5→1の循環
- 実際のAVAudioPlayerでのフェード中Pause/Resume、Restart、5→1
- 空の5Slot、6曲の拒否、選択順、置換、削除時の停止、再登録
- Security-Scoped Bookmarkの再解決、保存データからの復元、不正音声の拒否

実際のRain Lo-fi音源での聴感確認や数時間の連続運転は、使用する音声を登録して確認してください。
