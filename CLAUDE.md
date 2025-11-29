# CLAUDE.md

このファイルは、このリポジトリで Claude Code (claude.ai/code) が作業する際のガイダンスを提供します。

## プロジェクト概要

MacSysMonitor は CPU、メモリ、ネットワーク使用状況を監視する軽量 macOS メニューバーアプリケーションです。UI には SwiftUI、メニューバー表示に AppKit、システムメトリクス収集に低レベル macOS API を使用しています。アプリは Dock アイコンなしで動作し（LSUIElement=1）、メニューバーにリアルタイムグラフを表示します。

## ビルドコマンド

### 開発ビルド & 実行
```bash
# Xcode で開いて実行（⌘R）
open MacSysMonitor.xcodeproj

# またはコマンドラインでビルド
xcodebuild -project MacSysMonitor.xcodeproj -scheme MacSysMonitor -configuration Release -derivedDataPath build

# クイックビルドして /Applications にインストール
./scripts/run_local.sh
```

### 配布用ビルド
```bash
# DMG パッケージ作成（create-dmg ツールが必要）
./scripts/make_dmg.sh
# 出力先: dist/MacSysMonitor.dmg
```

## アーキテクチャ

### コアコンポーネント

**SystemMonitor** (`Sources/MacSysMonitor/SystemMonitor.swift`)
- 0.5〜10 秒ごとにシステムメトリクスを収集する中心的な `ObservableObject`（ユーザー設定可能）
- mach カーネル API を使用して CPU、メモリ、ネットワーク統計を収集：
  - `host_statistics` で CPU tick 差分を取得
  - `host_statistics64` で VM メモリページを取得
  - `getifaddrs` + `if_data` でネットワークバイトカウンタを取得
- 120 サンプルのローリングバッファを維持（`maxSamples`）
- Combine の `Timer.publish` によるタイマー駆動のリフレッシュ

**データフロー**
1. タイマーが `SystemMonitor.refresh()` を呼び出し → カーネル API からメトリクスを収集
2. 新しい `MetricsSample` を `samples` 配列に追加（公開プロパティ）
3. SwiftUI ビュー（`MenuBarIconView`、`DetailMenuView`）が変更を監視
4. `GraphView` がサンプル配列から Canvas ベースの折れ線グラフを描画

**メニューバー統合** (`Sources/MacSysMonitor/MacSysMonitorApp.swift`)
- `.window` スタイルの `MenuBarExtra` を使用（macOS 13+）
- ラベルにミニグラフを表示（`MenuBarIconView`）
- コンテンツに詳細ポップアップを表示（`DetailMenuView`）

**設定の永続化** (`Sources/MacSysMonitor/MonitorSettings.swift`)
- `updateInterval`（0.5〜10 秒）を `UserDefaults` でラップ
- 間隔変更時に `SystemMonitor.startTimer()` でタイマーを再起動

### メトリクス計算の詳細

**CPU 使用率**
- サンプル間の tick 差分からパーセンテージを計算
- user + system + nice tick を「使用中」、idle を「未使用」として追跡
- 最初のサンプルでは `nil` を返す（差分計算に前回の状態が必要）

**メモリ使用率**
- VM 統計から計算：active + inactive + wired + compressed ページ
- パーセンテージと絶対 MB 値の両方を報告
- 総メモリは `ProcessInfo.processInfo.physicalMemory` で一度取得

**ネットワーク使用量**
- すべてのアクティブなインターフェースを合算（`lo0` を除外）
- バイト差分と時間間隔から Mbps を計算
- アップロード/ダウンロードを個別に追跡、メニューバーには合計を表示

### UI コンポーネント

**GraphView**
- 汎用的な Canvas ベースの折れ線グラフレンダラー
- サンプル配列と値抽出クロージャを受け取る
- 値を 0〜1 範囲に正規化し、カラーコーディングでパスを描画：
  - 赤：CPU
  - 青：メモリ
  - 緑：ネットワーク（アップロード+ダウンロード合計）

**MenuBarIconView**
- 64x40px のコンパクトグラフと波形アイコン
- 現在のサンプル内のピーク Mbps に合わせてネットワークグラフを自動スケール

**DetailMenuView**
- フォーマット済みの行として現在のメトリクスを表示
- 60 ポイントの履歴グラフ
- 更新間隔のステッパーコントロール（UserDefaults に永続化）

## 開発メモ

### 言語 & フレームワーク
- Swift 5.9+ with SwiftUI and Combine
- 最小デプロイメントターゲット：macOS 14.0
- mach カーネル API 用の unsafe C interop を使用（`host_statistics`、`getifaddrs`）

### コードスタイル
- 4 スペースインデント
- ユーザー向けテキストは日本語文字列
- SwiftUI 命名規則（struct Views、@StateObject/@ObservedObject）

### デバッグのヒント
- LSUIElement=1 により Dock アイコンが非表示になるため、メニューバーが応答しなくなった場合はアクティビティモニタで終了
- `run_local.sh` のビルドログは `/tmp/macsysmonitor_build.log` に保存
- ネットワークメトリクスは最初のサンプルで 0 を表示することがある（差分計算に前回のカウンタが必要）

### プロジェクト構成
```
MacSysMonitor.xcodeproj/        # Xcode プロジェクト
MacSysMonitor/                  # リソース（Info.plist、AppIcon.icns）
Sources/MacSysMonitor/          # Swift ソースファイル
  MacSysMonitorApp.swift        # アプリエントリポイント、MenuBarExtra セットアップ
  SystemMonitor.swift           # メトリクス収集、タイマー、データモデル
  GraphView.swift               # Canvas 折れ線グラフレンダラー
  MenuBarViews.swift            # メニューバーアイコン + 詳細ポップアップ UI
  MonitorSettings.swift         # UserDefaults ラッパー
scripts/                        # ビルド自動化
  make_dmg.sh                   # DMG パッケージング（create-dmg を使用）
  run_local.sh                  # クイックビルド + インストール + 起動
build/                          # 派生データ（xcodebuild 出力）
dist/                           # 配布成果物（DMG）
```

### 署名 & 配布
- 開発：Xcode の Signing & Capabilities タブで自動署名
- 配布：`make_dmg.sh` が署名済み DMG をインストーラー UI 付きで作成
- DMG は AppleScript による Finder 自動化で Applications へのドラッグレイアウトを設定
