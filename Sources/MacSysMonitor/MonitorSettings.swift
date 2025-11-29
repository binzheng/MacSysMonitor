import Foundation

enum MetricType: String, CaseIterable {
    case cpu = "CPU"
    case memory = "メモリ"
    case network = "ネットワーク"
}

struct MonitorSettings {
    private enum Keys {
        static let interval = "MonitorUpdateInterval"
        static let metricType = "DisplayMetricType"
    }

    var updateInterval: TimeInterval {
        get {
            let value = UserDefaults.standard.double(forKey: Keys.interval)
            return value > 0 ? value : 1.0
        }
        set {
            let clamped = max(0.5, min(newValue, 10))
            UserDefaults.standard.set(clamped, forKey: Keys.interval)
        }
    }

    var displayMetricType: MetricType {
        get {
            let rawValue = UserDefaults.standard.string(forKey: Keys.metricType) ?? MetricType.cpu.rawValue
            return MetricType(rawValue: rawValue) ?? .cpu
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: Keys.metricType)
        }
    }
}
