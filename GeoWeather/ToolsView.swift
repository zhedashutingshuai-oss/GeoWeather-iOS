import SwiftUI
import QuartzCore
import CoreLocation
import UIKit

/// 帧率监测：CADisplayLink 数帧，0.5 秒结算一次
final class FPSMonitor: ObservableObject {
    @Published var fps: Int = 0
    private var link: CADisplayLink?
    private var frames = 0
    private var last: CFTimeInterval = 0

    func start() {
        guard link == nil else { return }
        let l = CADisplayLink(target: self, selector: #selector(tick(_:)))
        l.add(to: .main, forMode: .common)
        link = l
    }

    func stop() {
        link?.invalidate()
        link = nil
        frames = 0
        last = 0
    }

    @objc private func tick(_ l: CADisplayLink) {
        frames += 1
        if last == 0 { last = l.timestamp; return }
        let dt = l.timestamp - last
        if dt >= 0.5 {
            fps = Int((Double(frames) / dt).rounded())
            frames = 0
            last = l.timestamp
        }
    }
}

struct ToolsView: View {
    @EnvironmentObject var lm: LocationManager
    @StateObject private var fpsMonitor = FPSMonitor()
    @State private var demoOn = false
    @State private var copied = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "#3D7BDB"), Color(hex: "#7FB2F0")],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("工具")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(.white)
                    compassCard
                    coordsCard
                    fpsCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 56)
                .padding(.bottom, 110)
            }
        }
        .onAppear {
            lm.startLiveUpdates()
            fpsMonitor.start()
        }
        .onDisappear {
            lm.stopLiveUpdates()
            fpsMonitor.stop()
        }
    }

    // MARK: - 指南针

    private func directionName(_ deg: Double) -> String {
        let dirs = ["北", "东北", "东", "东南", "南", "西南", "西", "西北"]
        return dirs[Int((deg + 22.5) / 45) % 8]
    }

    private var compassCard: some View {
        Card(title: "指南针") {
            ZStack {
                ZStack {
                    ForEach(0..<24, id: \.self) { i in
                        Rectangle()
                            .fill(Color.white.opacity(i % 6 == 0 ? 0.9 : 0.35))
                            .frame(width: 2, height: i % 6 == 0 ? 13 : 7)
                            .offset(y: -86)
                            .rotationEffect(.degrees(Double(i) * 15))
                    }
                    ForEach(Array(["北", "东", "南", "西"].enumerated()), id: \.offset) { idx, label in
                        Text(label)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(label == "北" ? Color.red.opacity(0.95) : .white)
                            .offset(y: -62)
                            .rotationEffect(.degrees(Double(idx) * 90))
                    }
                }
                .rotationEffect(.degrees(-lm.heading))
                .animation(.linear(duration: 0.18), value: lm.heading)

                Image(systemName: "arrowtriangle.up.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.red)
                    .offset(y: -104)

                VStack(spacing: 0) {
                    Text("\(Int(lm.heading.rounded()))°")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(directionName(lm.heading))
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 216)
        }
    }

    // MARK: - 坐标

    private func coordRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.white.opacity(0.75))
            Spacer()
            Text(value).fontWeight(.medium).foregroundStyle(.white)
        }
        .font(.subheadline)
    }

    private var coordsCard: some View {
        Card(title: "坐标") {
            if let loc = lm.currentLocation {
                let lat = loc.coordinate.latitude
                let lon = loc.coordinate.longitude
                VStack(spacing: 8) {
                    coordRow("纬度", String(format: "%.5f° %@", abs(lat), lat >= 0 ? "N" : "S"))
                    coordRow("经度", String(format: "%.5f° %@", abs(lon), lon >= 0 ? "E" : "W"))
                    coordRow("海拔", String(format: "%.1f 米", loc.altitude))
                    coordRow("精度", String(format: "±%.0f 米", loc.horizontalAccuracy))
                    Button {
                        UIPasteboard.general.string = String(format: "%.5f, %.5f", lat, lon)
                        copied = true
                    } label: {
                        Label(copied ? "已复制" : "复制坐标", systemImage: copied ? "checkmark" : "doc.on.doc")
                            .font(.subheadline.weight(.medium))
                    }
                    .buttonStyle(.glass)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("定位中…").foregroundStyle(.white.opacity(0.85))
                    Button("重新定位") { lm.startLiveUpdates() }
                        .buttonStyle(.glass)
                        .foregroundStyle(.white)
                }
                .font(.subheadline)
            }
        }
    }

    // MARK: - 帧率

    private var fpsCard: some View {
        Card(title: "帧率演示") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(fpsMonitor.fps)")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("FPS · 屏幕最高 \(UIScreen.main.maximumFramesPerSecond) Hz")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.15)).frame(height: 26)
                        Circle().fill(Color.white)
                            .frame(width: 20, height: 20)
                            .offset(x: demoOn ? geo.size.width - 23 : 3)
                    }
                }
                .frame(height: 26)
                Text("小球匀速往返，越顺滑说明刷新率越高。")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .onAppear {
                withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: true)) {
                    demoOn = true
                }
            }
        }
    }
}
