# MacSysMonitor

macOS メニューバー常駐型の軽量ステータスモニターです。CPU / メモリ / ネットワーク（送受信）を 1 秒間隔で取得し、メニューバー上に簡易グラフを描画します。クリックすると詳細（％、MB、Mbps）がポップアップ表示されます。

## 必要環境
- macOS 13 以降 (Sonoma で確認想定)
- Xcode 15 / SwiftUI + AppKit

## プロジェクト構成
- `MacSysMonitor.xcodeproj` … Xcode プロジェクト
- `MacSysMonitor/Info.plist` … Dock を出さないための LSUIElement などを定義
- `Sources/MacSysMonitor/` … アプリ本体
  - `MacSysMonitorApp.swift` … `MenuBarExtra` エントリポイント
  - `SystemMonitor.swift` … CPU / メモリ / ネットワーク収集ロジック
  - `MonitorSettings.swift` … 更新間隔を `UserDefaults` に保存
  - `GraphView.swift` … メニューバーとメニュー内の折れ線グラフ描画
  - `MenuBarViews.swift` … アイコン表示と詳細メニュー UI

## ビルド & 実行手順
1. Xcode で `MacSysMonitor.xcodeproj` を開く。
2. ターゲットは `MacSysMonitor` のまま、`Signing & Capabilities` でチームを設定（開発用の自動署名で OK）。
3. Run（⌘R）するとメニューバー右上に小さなグラフが常駐します。クリックで詳細ドロップダウンを開きます。
4. Dock アイコンは表示されません（`LSUIElement=1`）。

## 使い方
- メニューバーのグラフは CPU=赤、メモリ=青、ネットワーク（送受合算）=緑。
- メニュー内には現在値を % / MB / Mbps で表示し、60 サンプルまでの履歴グラフを表示します。
- 「更新間隔」ステッパーで 0.5〜10 秒を設定すると `UserDefaults` に保存され、次回起動時も保持されます。

## データ取得方法
- CPU: `host_statistics` の CPU ticks 差分から使用率を算出
- メモリ: `host_statistics64` でページ情報を取得し、物理メモリに対する使用率を計算
- ネットワーク: `getifaddrs` で各 IF の `if_data` バイトカウンタを合算し、差分から Mbps を計算（`lo0` は除外）

## 自動起動 (LaunchAgent) 例
`~/Library/LaunchAgents/com.example.macsysmonitor.plist` を作成し、以下を保存してください（パスは自身のビルド結果に合わせて調整）。

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.example.macsysmonitor</string>
  <key>ProgramArguments</key>
  <array>
    <string>/Applications/MacSysMonitor.app/Contents/MacOS/MacSysMonitor</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <false/>
</dict>
</plist>
```

ロード方法:
```bash
launchctl load ~/Library/LaunchAgents/com.example.macsysmonitor.plist
```
アンロードは `launchctl unload ...` で行えます。

## 補足
- LSUIElement を使っているため Dock に表示されません。デバッグ中にメニューバーが消えた場合は Activity Monitor でプロセスを終了してください。
- 更新間隔を短くしすぎると自己負荷が増えるので 0.5〜1 秒程度を推奨します（目標 CPU 負荷 <3%）。
