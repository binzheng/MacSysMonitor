import SwiftUI
import AppKit

struct MenuBarIconView: View {
    @ObservedObject var monitor: SystemMonitor

    private var displayValue: String {
        guard let latest = monitor.latest else { return "--" }

        switch monitor.settings.displayMetricType {
        case .cpu:
            return String(format: "CPU %.0f%%", latest.cpuUsage)
        case .memory:
            return String(format: "MEM %.0f%%", latest.memoryUsage)
        case .network:
            return String(format: "NW %.1f", latest.uploadMbps + latest.downloadMbps)
        }
    }

    private var label: String {
        switch monitor.settings.displayMetricType {
        case .cpu:
            return "CPU"
        case .memory:
            return "MEM"
        case .network:
            return "NET"
        }
    }

    var body: some View {
        Text(displayValue)
            .font(.system(size: 11, weight: .semibold))
            .monospacedDigit()
            .padding(.horizontal, 6)
    }
}

struct DetailMenuView: View {
    @ObservedObject var monitor: SystemMonitor
    @State private var showSettings = false

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
                            "アイドル状態：\(String(format: "%.1f%%", latest.cpuIdle))"
                        ],
                        sparklineValues: cpuSparklineValues
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
                            "圧縮：\(String(format: "%.1f GB", latest.memoryCompressed))"
                        ]
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
                            "温度：\(String(format: "%.1f°C", latest.batteryTemperature))"
                        ],
                        progress: latest.batteryLevel / 100
                    )

                    sectionDivider

                    DetailMetricSection(
                        icon: "network",
                        title: "ネットワーク",
                        percentage: nil,
                        details: [
                            "ローカル IP：\(latest.localIP)",
                            "アップロード：\(String(format: "%.1f KB/s", latest.uploadMbps * 128))",
                            "ダウンロード：\(String(format: "%.1f KB/s", latest.downloadMbps * 128))"
                        ],
                        subtitle: "Wi-Fi"
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
        .padding(.vertical, 18)
        .padding(.horizontal, 16)
        .frame(width: 360, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(panelGradient)
                .shadow(color: Color.black.opacity(0.18), radius: 14, x: 0, y: 10)
        )
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
    }

    private var panelGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.90, green: 0.91, blue: 0.93),
                Color(red: 0.82, green: 0.84, blue: 0.86)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var sectionDivider: some View {
        Divider()
            .overlay(Color.black.opacity(0.08))
            .padding(.vertical, 12)
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            DisclosureGroup(isExpanded: $showSettings) {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("メニューバー表示")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.black.opacity(0.8))
                        Picker("", selection: Binding(
                            get: { monitor.settings.displayMetricType },
                            set: { monitor.settings.displayMetricType = $0 }
                        )) {
                            ForEach(MetricType.allCases, id: \.self) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    Divider().overlay(Color.black.opacity(0.08))

                    VStack(alignment: .leading, spacing: 6) {
                        Text("更新間隔")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.black.opacity(0.8))
                        Stepper(value: Binding(
                            get: { monitor.settings.updateInterval },
                            set: {
                                monitor.settings.updateInterval = $0
                                monitor.startTimer()
                            }
                        ), in: 0.5...10, step: 0.5) {
                            Text("\(monitor.settings.updateInterval, specifier: "%.1f") 秒")
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
                                .foregroundStyle(Color.red)
                                .bold()
                            Spacer()
                        }
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.top, 8)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.black.opacity(0.75))
                    Text("設定")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.black.opacity(0.9))
                    Spacer()
                }
            }
            .accentColor(.black)
        }
    }
}

// 詳細メトリクスセクション（画像のようなレイアウト）
struct DetailMetricSection: View {
    let icon: String
    let title: String
    let percentage: Double?
    let details: [String]
    var subtitle: String? = nil
    var progress: Double? = nil
    var sparklineValues: [Double] = []

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.4))
                    .frame(width: 54, height: 54)
                    .shadow(color: Color.black.opacity(0.05), radius: 2, y: 1)

                Image(systemName: icon)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.82))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(titleText)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.9))

                ForEach(details, id: \.self) { detail in
                    Text(detail)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.black.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !sparklineValues.isEmpty {
                    SparklineView(values: sparklineValues)
                        .frame(height: 18)
                }

                if let progress {
                    MetricBar(progress: progress)
                        .frame(height: 10)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 6)
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

struct SparklineView: View {
    let values: [Double]

    var body: some View {
        Canvas { context, size in
            let recent = Array(values.suffix(40))
            guard let minValue = recent.min(), let maxValue = recent.max(), !recent.isEmpty else { return }

            let range = max(maxValue - minValue, 0.001)
            let stepX = size.width / CGFloat(max(recent.count - 1, 1))

            let points: [CGPoint] = recent.enumerated().map { index, value in
                let normalized = (value - minValue) / range
                let x = CGFloat(index) * stepX
                let y = size.height - CGFloat(normalized) * size.height
                return CGPoint(x: x, y: y)
            }

            guard let first = points.first, let last = points.last else { return }

            var linePath = Path()
            linePath.move(to: first)
            points.dropFirst().forEach { linePath.addLine(to: $0) }

            var fillPath = Path()
            fillPath.move(to: CGPoint(x: first.x, y: size.height))
            fillPath.addLine(to: first)
            points.dropFirst().forEach { fillPath.addLine(to: $0) }
            fillPath.addLine(to: CGPoint(x: last.x, y: size.height))
            fillPath.closeSubpath()

            let gradient = Gradient(colors: [Color.blue.opacity(0.28), Color.blue.opacity(0.05)])
            context.fill(fillPath, with: .linearGradient(gradient, startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: 0, y: size.height)))
            context.stroke(linePath, with: .color(Color.blue), lineWidth: 2)
        }
    }
}

// クリック可能なメトリクス行（旧版、互換性のため残す）
struct MetricSelectableRow: View {
    let metricType: MetricType
    let label: String
    let value: String
    let color: Color
    let isSelected: Bool
    let samples: [MetricsSample]
    let valueExtractor: (MetricsSample) -> Double
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    // 色インジケーター
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)

                    // ラベル
                    Text(label)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.black)

                    Spacer()

                    // 値
                    Text(value)
                        .font(.system(size: 13))
                        .foregroundColor(.black)

                    // チェックマーク（右端）
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.blue)
                    } else {
                        Image(systemName: "circle")
                            .font(.system(size: 16))
                            .foregroundColor(.gray.opacity(0.3))
                    }
                }

                // 小さいグラフ
                if !samples.isEmpty {
                    MiniGraphView(
                        samples: samples,
                        color: color,
                        valueExtractor: valueExtractor
                    )
                    .frame(height: 30)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isSelected ? Color.blue.opacity(0.08) : Color.clear)
        .cornerRadius(6)
    }
}

// ミニグラフビュー
struct MiniGraphView: View {
    let samples: [MetricsSample]
    let color: Color
    let valueExtractor: (MetricsSample) -> Double

    var body: some View {
        Canvas { context, size in
            guard samples.count > 1 else { return }

            let recentSamples = samples.suffix(60)
            let count = recentSamples.count
            let stepX = size.width / CGFloat(max(count - 1, 1))

            var path = Path()
            for (index, sample) in recentSamples.enumerated() {
                let x = CGFloat(index) * stepX
                let normalized = min(max(valueExtractor(sample), 0), 1)
                let y = size.height - (CGFloat(normalized) * size.height)

                if index == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }

            context.stroke(path, with: .color(color), lineWidth: 1.5)
        }
    }
}
