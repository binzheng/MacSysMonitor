import AppKit
import SwiftUI

struct MenuBarIconView: View {
    @ObservedObject var monitor: SystemMonitor

    private var displayValue: String {
        guard let latest = monitor.latest else { return "--" }

        switch monitor.settings.displayMetricType {
        case .cpu:
            return String(format: "%.0f%%", latest.cpuUsage)
        case .memory:
            return String(format: "%.0f%%", latest.memoryUsage)
        case .network:
            return String(format: "%.1f", latest.uploadMbps + latest.downloadMbps)
        }
    }

    private var iconName: String {
        switch monitor.settings.displayMetricType {
        case .cpu:
            return "cpu"
        case .memory:
            return "memorychip"
        case .network:
            return "network"
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconName)
                .font(.system(size: 15, weight: .semibold))
            Text(displayValue)
                .font(.system(size: 13, weight: .semibold))
                .monospacedDigit()
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 1)
        .frame(width: 60)
    }
}

struct DetailMenuView: View {
    @ObservedObject var monitor: SystemMonitor

    private var latest: MetricsSample? { monitor.latest }
    private var cpuSparklineValues: [Double] { monitor.samples.map { $0.cpuUsage / 100 } }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let latest {
                VStack(alignment: .leading, spacing: 0) {
                    DetailMetricSection(
                        icon: "cpu",
                        title: "CPU",
                        percentage: latest.cpuUsage,
                        details: [
                            "システム：\(String(format: "%.1f%%", latest.cpuSystem))",
                            "ユーザ：\(String(format: "%.1f%%", latest.cpuUser))",
                            "アイドル状態：\(String(format: "%.1f%%", latest.cpuIdle))",
                        ],
                        progress: latest.cpuUsage / 100,
                        onTap: {
                            monitor.settings.displayMetricType = .cpu
                        }
                    )

                    sectionDivider

                    DetailMetricSection(
                        icon: "memorychip",
                        title: "メモリ",
                        percentage: latest.memoryUsage,
                        details: [
                            "プレッシャー：\(String(format: "%.1f%%", latest.memoryPressure))",
                            "アプリメモリ：\(String(format: "%.1f GB", latest.memoryApp))",
                            "確保されているメモリ：\(String(format: "%.1f GB", latest.memoryWired))",
                            "圧縮：\(String(format: "%.1f GB", latest.memoryCompressed))",
                        ],
                        onTap: {
                            monitor.settings.displayMetricType = .memory
                        }
                    )

                    sectionDivider

                    DetailMetricSection(
                        icon: "internaldrive",
                        title: "ストレージ",
                        percentage: latest.storageUsage,
                        details: [
                            "\(String(format: "%.1f GB", latest.storageUsedGB)) / \(String(format: "%.1f GB", latest.storageTotalGB))"
                        ],
                        subtitle: "使用中",
                        progress: latest.storageUsage / 100
                    )

                    sectionDivider

                    DetailMetricSection(
                        icon: "battery.100",
                        title: "バッテリー",
                        percentage: latest.batteryLevel,
                        details: [
                            "供給源：\(latest.batteryIsCharging ? "電源アダプタ" : "バッテリー")",
                            "最大容量：\(String(format: "%.1f%%", latest.batteryCapacity))",
                            "充放電回数：\(latest.batteryCycleCount)",
                            "温度：\(String(format: "%.1f°C", latest.batteryTemperature))",
                        ]
                    )

                    sectionDivider

                    DetailMetricSection(
                        icon: "network",
                        title: "ネットワーク",
                        percentage: nil,
                        details: [
                            "ローカル IP：\(latest.localIP)",
                            "アップロード：\(String(format: "%.1f KB/s", latest.uploadMbps * 128))",
                            "ダウンロード：\(String(format: "%.1f KB/s", latest.downloadMbps * 128))",
                        ],
                        subtitle: "Wi-Fi",
                        onTap: {
                            monitor.settings.displayMetricType = .network
                        }
                    )
                }
            } else {
                Text("読み込み中...")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.8))
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            if latest != nil {
                sectionDivider
            }

            settingsSection
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .frame(width: 320, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(panelGradient)
                .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 6)
        )
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
    }

    private var panelGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.90, green: 0.91, blue: 0.93),
                Color(red: 0.82, green: 0.84, blue: 0.86),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var sectionDivider: some View {
        Divider()
            .overlay(Color.black.opacity(0.08))
            .padding(.vertical, 6)
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 4) {
                Text("更新間隔")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.8))
                Spacer()
                Stepper(
                    value: Binding(
                        get: { monitor.settings.updateInterval },
                        set: {
                            monitor.settings.updateInterval = $0
                            monitor.startTimer()
                        }
                    ), in: 0.5...10, step: 0.5
                ) {
                    Text("\(monitor.settings.updateInterval, specifier: "%.1f") 秒")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.black.opacity(0.9))
                }
            }

            Divider().overlay(Color.black.opacity(0.08))

            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                HStack {
                    Spacer()
                    Text("終了")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.red)
                        .bold()
                    Spacer()
                }
            }
            .buttonStyle(.bordered)
        }
    }
}

// 詳細メトリクスセクション
struct DetailMetricSection: View {
    let icon: String
    let title: String
    let percentage: Double?
    let details: [String]
    var subtitle: String? = nil
    var progress: Double? = nil
    var onTap: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            ZStack(alignment: .center) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(red: 0.86, green: 0.875, blue: 0.895).opacity(0.05))
                    .frame(width: 42, height: 42)
                    .shadow(color: Color.black.opacity(0.05), radius: 2, y: 1)

                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.82))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(titleText)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.9))

                ForEach(details, id: \.self) { detail in
                    Text(detail)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.black.opacity(0.8))
                        .padding(.horizontal, 12)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let progress {
                    MetricBar(progress: progress)
                        .frame(height: 7)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?()
        }
    }

    private var titleText: String {
        if let percentage {
            let percentText = String(format: "%.1f%%", percentage)
            if let subtitle, !subtitle.isEmpty {
                return "\(title) ： \(percentText) \(subtitle)"
            }
            return "\(title) ： \(percentText)"
        }
        if let subtitle {
            return "\(title) ： \(subtitle)"
        }
        return title
    }
}

struct MetricBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { geometry in
            let clamped = min(max(progress, 0), 1)
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.black.opacity(0.08))

                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.blue)
                    .frame(width: geometry.size.width * CGFloat(clamped))
            }
        }
    }
}
