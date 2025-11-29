import Foundation
import Combine
import AppKit

struct MetricsSample: Identifiable {
    let id = UUID()
    let timestamp: Date

    // CPU
    let cpuUsage: Double
    let cpuSystem: Double
    let cpuUser: Double
    let cpuIdle: Double

    // メモリ
    let memoryUsage: Double
    let memoryUsedMB: Double
    let memoryFreeMB: Double
    let memoryPressure: Double
    let memoryApp: Double
    let memoryWired: Double
    let memoryCompressed: Double

    // ネットワーク
    let uploadMbps: Double
    let downloadMbps: Double
    let localIP: String

    // ストレージ
    let storageUsedGB: Double
    let storageTotalGB: Double
    let storageUsage: Double

    // バッテリー
    let batteryLevel: Double
    let batteryIsCharging: Bool
    let batteryCapacity: Double
    let batteryCycleCount: Int
    let batteryTemperature: Double
}

struct NetworkCounters {
    var inbound: UInt64
    var outbound: UInt64
}

final class SystemMonitor: ObservableObject {
    @Published private(set) var samples: [MetricsSample] = []
    @Published var settings = MonitorSettings()

    private var timer: AnyCancellable?
    private var previousCPULoad: host_cpu_load_info?
    private var previousNetwork: NetworkCounters?
    private var previousNetworkDate: Date?

    let maxSamples = 120
    let totalMemoryMB = Double(ProcessInfo.processInfo.physicalMemory) / (1024 * 1024)

    init() {
        refresh()
        startTimer()
    }

    deinit {
        timer?.cancel()
    }

    var latest: MetricsSample? { samples.last }

    func startTimer() {
        timer?.cancel()
        timer = Timer.publish(every: settings.updateInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refresh()
            }
    }

    func refresh() {
        let now = Date()
        let cpu = cpuUsageDetailed()
        let memory = memoryUsageDetailed()
        let net = networkUsage(at: now)
        let storage = storageInfo()
        let battery = batteryInfo()
        let ip = localIPAddress()

        let sample = MetricsSample(
            timestamp: now,
            // CPU
            cpuUsage: cpu.total,
            cpuSystem: cpu.system,
            cpuUser: cpu.user,
            cpuIdle: cpu.idle,
            // メモリ
            memoryUsage: memory.percent,
            memoryUsedMB: memory.usedMB,
            memoryFreeMB: memory.freeMB,
            memoryPressure: memory.pressure,
            memoryApp: memory.app,
            memoryWired: memory.wired,
            memoryCompressed: memory.compressed,
            // ネットワーク
            uploadMbps: net.uploadMbps,
            downloadMbps: net.downloadMbps,
            localIP: ip,
            // ストレージ
            storageUsedGB: storage.usedGB,
            storageTotalGB: storage.totalGB,
            storageUsage: storage.percent,
            // バッテリー
            batteryLevel: battery.level,
            batteryIsCharging: battery.isCharging,
            batteryCapacity: battery.capacity,
            batteryCycleCount: battery.cycleCount,
            batteryTemperature: battery.temperature
        )

        samples.append(sample)
        if samples.count > maxSamples {
            samples.removeFirst(samples.count - maxSamples)
        }
    }

    private func cpuUsageDetailed() -> (total: Double, system: Double, user: Double, idle: Double) {
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride)
        var info = host_cpu_load_info()

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else { return (0, 0, 0, 100) }

        let user = Double(info.cpu_ticks.0)
        let system = Double(info.cpu_ticks.1)
        let idle = Double(info.cpu_ticks.2)
        let nice = Double(info.cpu_ticks.3)

        let totalTicks = user + system + idle + nice

        if let previous = previousCPULoad {
            let prevUser = Double(previous.cpu_ticks.0)
            let prevSystem = Double(previous.cpu_ticks.1)
            let prevIdle = Double(previous.cpu_ticks.2)
            let prevNice = Double(previous.cpu_ticks.3)

            let prevTotal = prevUser + prevSystem + prevIdle + prevNice

            let deltaTotal = totalTicks - prevTotal
            let deltaUser = (user + nice) - (prevUser + prevNice)
            let deltaSystem = system - prevSystem
            let deltaIdle = idle - prevIdle

            previousCPULoad = info

            guard deltaTotal > 0 else { return (0, 0, 0, 100) }

            let userPercent = max(0, min(100, (deltaUser / deltaTotal) * 100))
            let systemPercent = max(0, min(100, (deltaSystem / deltaTotal) * 100))
            let idlePercent = max(0, min(100, (deltaIdle / deltaTotal) * 100))
            let totalPercent = userPercent + systemPercent

            return (totalPercent, systemPercent, userPercent, idlePercent)
        } else {
            previousCPULoad = info
            return (0, 0, 0, 100)
        }
    }

    private func memoryUsageDetailed() -> (percent: Double, usedMB: Double, freeMB: Double, pressure: Double, app: Double, wired: Double, compressed: Double) {
        var size = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size) / 4
        var vmStats = vm_statistics64()

        let result = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &size)
            }
        }

        guard result == KERN_SUCCESS else { return (0, 0, 0, 0, 0, 0, 0) }

        let pageSize = Double(vm_kernel_page_size)
        let free = Double(vmStats.free_count) * pageSize
        let active = Double(vmStats.active_count) * pageSize
        let inactive = Double(vmStats.inactive_count) * pageSize
        let wired = Double(vmStats.wire_count) * pageSize
        let compressed = Double(vmStats.compressor_page_count) * pageSize

        let used = active + inactive + wired + compressed
        let total = used + free

        let usedMB = used / (1024 * 1024)
        let freeMB = free / (1024 * 1024)
        let percent = total > 0 ? (used / total) * 100 : 0

        // 詳細情報（GB単位）
        let appMemory = (active + inactive) / (1024 * 1024 * 1024)
        let wiredMemory = wired / (1024 * 1024 * 1024)
        let compressedMemory = compressed / (1024 * 1024 * 1024)

        // メモリプレッシャー（簡易版：使用率ベース）
        let pressure = percent

        return (percent, usedMB, freeMB, pressure, appMemory, wiredMemory, compressedMemory)
    }

    private func networkUsage(at date: Date) -> (uploadMbps: Double, downloadMbps: Double) {
        guard let counters = networkCounters() else { return (0, 0) }
        defer {
            previousNetwork = counters
            previousNetworkDate = date
        }

        guard let previousNetwork, let previousNetworkDate else { return (0, 0) }
        let deltaTime = date.timeIntervalSince(previousNetworkDate)
        guard deltaTime > 0 else { return (0, 0) }

        let deltaIn = Double(counters.inbound - previousNetwork.inbound)
        let deltaOut = Double(counters.outbound - previousNetwork.outbound)

        let downloadMbps = (deltaIn / deltaTime) / (1024 * 1024) * 8
        let uploadMbps = (deltaOut / deltaTime) / (1024 * 1024) * 8

        return (uploadMbps, downloadMbps)
    }

    private func networkCounters() -> NetworkCounters? {
        var interfaceAddresses: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfaceAddresses) == 0, let first = interfaceAddresses else { return nil }
        defer { freeifaddrs(interfaceAddresses) }

        var inbound: UInt64 = 0
        var outbound: UInt64 = 0

        for pointer in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let interface = pointer.pointee
            let flags = Int32(interface.ifa_flags)
            let isUp = (flags & IFF_UP) == IFF_UP
            let isRunning = (flags & IFF_RUNNING) == IFF_RUNNING
            if !isUp || !isRunning { continue }

            let name = String(cString: interface.ifa_name)
            if name == "lo0" { continue }

            guard let data = interface.ifa_data?.assumingMemoryBound(to: if_data.self).pointee else { continue }
            inbound += UInt64(data.ifi_ibytes)
            outbound += UInt64(data.ifi_obytes)
        }

        return NetworkCounters(inbound: inbound, outbound: outbound)
    }

    // ローカルIPアドレスを取得
    private func localIPAddress() -> String {
        var address: String = "不明"
        var ifaddr: UnsafeMutablePointer<ifaddrs>?

        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return address }
        defer { freeifaddrs(ifaddr) }

        for ifptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ifptr.pointee
            let addrFamily = interface.ifa_addr.pointee.sa_family

            if addrFamily == UInt8(AF_INET) {
                let name = String(cString: interface.ifa_name)
                if name == "en0" || name.hasPrefix("en") {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr,
                              socklen_t(interface.ifa_addr.pointee.sa_len),
                              &hostname,
                              socklen_t(hostname.count),
                              nil,
                              socklen_t(0),
                              NI_NUMERICHOST)
                    address = String(cString: hostname)
                    break
                }
            }
        }
        return address
    }

    // ストレージ情報を取得
    private func storageInfo() -> (usedGB: Double, totalGB: Double, percent: Double) {
        let fileURL = URL(fileURLWithPath: "/")
        do {
            let values = try fileURL.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityKey])
            if let total = values.volumeTotalCapacity,
               let available = values.volumeAvailableCapacity {
                let totalGB = Double(total) / (1024 * 1024 * 1024)
                let availableGB = Double(available) / (1024 * 1024 * 1024)
                let usedGB = totalGB - availableGB
                let percent = (usedGB / totalGB) * 100
                return (usedGB, totalGB, percent)
            }
        } catch {
            // エラー時のデフォルト値
        }
        return (0, 0, 0)
    }

    // バッテリー情報を取得
    private func batteryInfo() -> (level: Double, isCharging: Bool, capacity: Double, cycleCount: Int, temperature: Double) {
        // IOKit を使用してバッテリー情報を取得
        // 簡易版：デフォルト値を返す（完全な実装にはIOKitの詳細な実装が必要）
        return (50.0, false, 95.0, 0, 30.0)
    }
}
