import XCTest
@testable import MacSysMonitor

final class MonitorSettingsTests: XCTestCase {
    private let intervalKey = "MonitorUpdateInterval"
    private let metricKey = "DisplayMetricType"
    private var originalInterval: Any?
    private var originalMetric: Any?

    override func setUp() {
        super.setUp()
        originalInterval = UserDefaults.standard.object(forKey: intervalKey)
        originalMetric = UserDefaults.standard.object(forKey: metricKey)
        UserDefaults.standard.removeObject(forKey: intervalKey)
        UserDefaults.standard.removeObject(forKey: metricKey)
    }

    override func tearDown() {
        if let originalInterval {
            UserDefaults.standard.set(originalInterval, forKey: intervalKey)
        } else {
            UserDefaults.standard.removeObject(forKey: intervalKey)
        }

        if let originalMetric {
            UserDefaults.standard.set(originalMetric, forKey: metricKey)
        } else {
            UserDefaults.standard.removeObject(forKey: metricKey)
        }

        super.tearDown()
    }

    func testDefaultValuesUseFallbacks() {
        let settings = MonitorSettings()

        XCTAssertEqual(settings.updateInterval, 1.0, accuracy: 0.0001)
        XCTAssertEqual(settings.displayMetricType, .cpu)
    }

    func testUpdateIntervalIsClampedBetweenHalfAndTenSeconds() {
        var settings = MonitorSettings()

        settings.updateInterval = 0.1
        XCTAssertEqual(settings.updateInterval, 0.5, accuracy: 0.0001)

        settings.updateInterval = 20
        XCTAssertEqual(settings.updateInterval, 10.0, accuracy: 0.0001)

        settings.updateInterval = 2.5
        XCTAssertEqual(settings.updateInterval, 2.5, accuracy: 0.0001)
    }

    func testDisplayMetricTypePersistsSelection() {
        var settings = MonitorSettings()
        settings.displayMetricType = .memory

        XCTAssertEqual(settings.displayMetricType, .memory)

        UserDefaults.standard.set("Unknown", forKey: metricKey)
        XCTAssertEqual(settings.displayMetricType, .cpu)
    }
}

@MainActor
final class SystemMonitorTests: XCTestCase {
    private var monitor: SystemMonitor!

    override func setUp() async throws {
        try await super.setUp()
        monitor = SystemMonitor()
        // 初期化後、少し待機してメトリクスが収集されるのを待つ
        try await Task.sleep(for: .milliseconds(100))
    }

    override func tearDown() async throws {
        monitor = nil
        try await super.tearDown()
    }

    func testRefreshDoesNotExceedMaxSamples() {
        let originalFirstID = monitor.samples.first?.id

        for _ in 0..<(monitor.maxSamples + 5) {
            monitor.refresh()
        }

        XCTAssertEqual(monitor.samples.count, monitor.maxSamples)

        if let originalFirstID {
            let containsOriginal = monitor.samples.contains { $0.id == originalFirstID }
            XCTAssertFalse(containsOriginal, "Oldest sample should be pruned when exceeding maxSamples")
        }

        let timestamps = monitor.samples.map { $0.timestamp }
        XCTAssertEqual(timestamps, timestamps.sorted(), "Samples should remain in chronological order")
    }

    func testLatestSampleReturnsLastSample() {
        // 初期状態でサンプルが存在する
        XCTAssertNotNil(monitor.latest, "Should have at least one sample after initialization")

        // 追加のrefresh後、latestが最新のサンプルを返す
        monitor.refresh()
        let latestSample = monitor.latest
        XCTAssertEqual(latestSample?.id, monitor.samples.last?.id, "latest should return the most recent sample")
    }

    func testCPUUsageIsWithinValidRange() {
        guard let sample = monitor.latest else {
            XCTFail("No sample available")
            return
        }

        XCTAssertGreaterThanOrEqual(sample.cpuUsage, 0, "CPU usage should not be negative")
        XCTAssertLessThanOrEqual(sample.cpuUsage, 100, "CPU usage should not exceed 100%")
        XCTAssertGreaterThanOrEqual(sample.cpuSystem, 0, "CPU system should not be negative")
        XCTAssertGreaterThanOrEqual(sample.cpuUser, 0, "CPU user should not be negative")
        XCTAssertGreaterThanOrEqual(sample.cpuIdle, 0, "CPU idle should not be negative")
    }

    func testMemoryMetricsAreValid() {
        guard let sample = monitor.latest else {
            XCTFail("No sample available")
            return
        }

        XCTAssertGreaterThanOrEqual(sample.memoryUsage, 0, "Memory usage should not be negative")
        XCTAssertLessThanOrEqual(sample.memoryUsage, 100, "Memory usage should not exceed 100%")
        XCTAssertGreaterThanOrEqual(sample.memoryUsedMB, 0, "Used memory should not be negative")
        XCTAssertGreaterThanOrEqual(sample.memoryFreeMB, 0, "Free memory should not be negative")
        XCTAssertGreaterThanOrEqual(sample.memoryPressure, 0, "Memory pressure should not be negative")
        XCTAssertLessThanOrEqual(sample.memoryPressure, 100, "Memory pressure should not exceed 100%")
        XCTAssertGreaterThanOrEqual(sample.memoryApp, 0, "App memory should not be negative")
        XCTAssertGreaterThanOrEqual(sample.memoryWired, 0, "Wired memory should not be negative")
        XCTAssertGreaterThanOrEqual(sample.memoryCompressed, 0, "Compressed memory should not be negative")
    }

    func testStorageMetricsAreValid() {
        guard let sample = monitor.latest else {
            XCTFail("No sample available")
            return
        }

        XCTAssertGreaterThanOrEqual(sample.storageUsedGB, 0, "Storage used should not be negative")
        XCTAssertGreaterThanOrEqual(sample.storageTotalGB, 0, "Storage total should not be negative")
        XCTAssertGreaterThanOrEqual(sample.storageUsage, 0, "Storage usage should not be negative")
        XCTAssertLessThanOrEqual(sample.storageUsage, 100, "Storage usage should not exceed 100%")

        if sample.storageTotalGB > 0 {
            XCTAssertLessThanOrEqual(sample.storageUsedGB, sample.storageTotalGB, "Used storage should not exceed total storage")
        }
    }

    func testBatteryMetricsAreValid() {
        guard let sample = monitor.latest else {
            XCTFail("No sample available")
            return
        }

        // バッテリーが存在しない場合は0を返す
        XCTAssertGreaterThanOrEqual(sample.batteryLevel, 0, "Battery level should not be negative")
        XCTAssertLessThanOrEqual(sample.batteryLevel, 100, "Battery level should not exceed 100%")
        XCTAssertGreaterThanOrEqual(sample.batteryCapacity, 0, "Battery capacity should not be negative")
        XCTAssertGreaterThanOrEqual(sample.batteryCycleCount, 0, "Battery cycle count should not be negative")

        // 温度は摂氏で-50〜100度の範囲内が妥当
        if sample.batteryTemperature != 0 {
            XCTAssertGreaterThanOrEqual(sample.batteryTemperature, -50, "Battery temperature seems too low")
            XCTAssertLessThanOrEqual(sample.batteryTemperature, 100, "Battery temperature seems too high")
        }
    }

    func testNetworkMetricsAreValid() {
        guard let sample = monitor.latest else {
            XCTFail("No sample available")
            return
        }

        XCTAssertGreaterThanOrEqual(sample.uploadMbps, 0, "Upload speed should not be negative")
        XCTAssertGreaterThanOrEqual(sample.downloadMbps, 0, "Download speed should not be negative")
        XCTAssertNotEqual(sample.localIP, "", "Local IP should not be empty")
    }

    func testTimestampsAreMonotonicIncreasing() {
        for _ in 0..<5 {
            monitor.refresh()
        }

        let timestamps = monitor.samples.map { $0.timestamp }

        for i in 1..<timestamps.count {
            XCTAssertGreaterThanOrEqual(timestamps[i], timestamps[i-1], "Timestamps should be monotonically increasing")
        }
    }

    func testTotalMemoryIsPositive() {
        XCTAssertGreaterThan(monitor.totalMemoryMB, 0, "Total memory should be positive")
        XCTAssertGreaterThan(monitor.totalMemoryMB, 1024, "Total memory should be at least 1GB")
    }
}
