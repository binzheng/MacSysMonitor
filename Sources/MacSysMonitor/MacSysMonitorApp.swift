import AppKit
import SwiftUI

@main
struct MacSysMonitorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

// borderlessウィンドウでもキーウィンドウになれるようにする
class BorderlessWindow: NSWindow {
    override var canBecomeKey: Bool {
        return true
    }

    override var canBecomeMain: Bool {
        return true
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var statusItem: NSStatusItem?
    var detailWindow: NSWindow?
    var monitor = SystemMonitor()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // ステータスバーアイテムを作成
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            // ステータスバーアイコンを設定
            updateStatusBarIcon()

            // クリックイベントを設定
            button.action = #selector(toggleWindow)
            button.target = self
        }

        // ウィンドウを作成（一度だけ）
        createWindow()

        // 定期的にステータスバーアイコンを更新
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateStatusBarIcon()
            }
        }
    }

    private func createWindow() {
        // BorderlessWindowを使用してウィンドウを作成
        let window = BorderlessWindow(
            contentRect: NSRect(x: 0, y: 0, width: 416, height: 630),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.level = .popUpMenu
        window.delegate = self

        // SwiftUI コンテンツを設定
        let hostingView = NSHostingView(rootView: DetailMenuView(monitor: monitor))
        window.contentView = hostingView

        detailWindow = window
    }

    @objc func toggleWindow(_ sender: AnyObject?) {
        guard let button = statusItem?.button, let window = detailWindow else { return }

        if window.isVisible {
            // 表示中なら非表示にする
            window.orderOut(nil)
        } else {
            // 非表示なら表示する
            showWindow(relativeTo: button)
        }
    }

    private func showWindow(relativeTo button: NSStatusBarButton) {
        guard let window = detailWindow else { return }

        // ウィンドウの位置を計算（ステータスバーアイコンの下）
        let buttonRect = button.window?.convertToScreen(button.frame) ?? .zero
        let screenFrame = NSScreen.main?.visibleFrame ?? .zero

        let windowX = buttonRect.midX - (window.frame.width / 2)
        let windowY = buttonRect.minY - window.frame.height + 2

        // 画面の端からはみ出さないように調整
        let adjustedX = max(
            screenFrame.minX + 8, min(windowX, screenFrame.maxX - window.frame.width - 8))

        window.setFrameOrigin(NSPoint(x: adjustedX, y: windowY))
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    // ウィンドウを閉じてもアプリを終了しない
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationDidResignActive(_ notification: Notification) {
        detailWindow?.orderOut(nil)
    }

    // NSWindowDelegate - フォーカスを失ったら非表示にする（閉じない）
    func windowDidResignKey(_ notification: Notification) {
        if let window = notification.object as? NSWindow, window == detailWindow {
            window.orderOut(nil)
        }
    }

    func updateStatusBarIcon() {
        guard let button = statusItem?.button else { return }

        let iconView = MenuBarIconView(monitor: monitor)
        let renderer = ImageRenderer(content: iconView)
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2.0

        if let nsImage = renderer.nsImage {
            nsImage.isTemplate = true
            button.image = nsImage
        }
    }
}
