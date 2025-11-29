import SwiftUI
import Combine

@main
struct MacSysMonitorApp: App {
    @StateObject private var monitor = SystemMonitor()

    var body: some Scene {
        MenuBarExtra {
            DetailMenuView(monitor: monitor)
        } label: {
            MenuBarIconView(monitor: monitor)
        }
    }
}
