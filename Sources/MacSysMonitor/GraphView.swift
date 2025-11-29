import SwiftUI

struct GraphView: View {
    let samples: [MetricsSample]
    let maxNetworkMbps: Double
    let height: CGFloat

    private let cpuColor = Color.red
    private let memoryColor = Color.blue
    private let networkColor = Color.green

    var body: some View {
        Canvas { context, size in
            guard samples.count > 1 else { return }

            let cpuPath = makePath(size: size) { $0.cpuUsage / 100 }
            context.stroke(cpuPath, with: .color(cpuColor), lineWidth: 1.4)

            let memoryPath = makePath(size: size) { $0.memoryUsage / 100 }
            context.stroke(memoryPath, with: .color(memoryColor), lineWidth: 1.4)

            let networkPath = makePath(size: size) {
                guard maxNetworkMbps > 0 else { return 0 }
                return min(1, ($0.uploadMbps + $0.downloadMbps) / maxNetworkMbps)
            }
            context.stroke(networkPath, with: .color(networkColor), lineWidth: 1.2)
        }
        .frame(height: height)
        .drawingGroup()
    }

    private func makePath(size: CGSize, value: (MetricsSample) -> Double) -> Path {
        var path = Path()
        let count = samples.count
        let stepX = size.width / CGFloat(max(count - 1, 1))

        for (index, sample) in samples.enumerated() {
            let x = CGFloat(index) * stepX
            let normalized = min(max(value(sample), 0), 1)
            let y = size.height - (CGFloat(normalized) * size.height)

            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        return path
    }
}
