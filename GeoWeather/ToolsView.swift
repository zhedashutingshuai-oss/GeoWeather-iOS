import SwiftUI
import CoreLocation
import UIKit

struct ToolsView: View {
    @EnvironmentObject var lm: LocationManager
    @State private var copied = false
    @AppStorage("appearanceMode") private var appearanceMode = "system"
    @Namespace private var appearanceNS

    var body: some View {
        ZStack {
            PageGradient()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("工具")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(.white)
                    appearanceCard
                    compassCard
                    coordsCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 56)
                .padding(.bottom, 28)
            }
        }
        .onAppear { lm.startLiveUpdates() }
        .onDisappear { lm.stopLiveUpdates() }
    }

    // MARK: - 外观

    private var appearanceCard: some View {
        Card(title: "外观") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 0) {
                    ForEach([("light", "浅色"), ("dark", "深色"), ("system", "按日出日落")], id: \.0) { opt in
                        Button {
                            withAnimation(.easeInOut(duration: 0.22)) { appearanceMode = opt.0 }
                        } label: {
                            Text(opt.1)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(appearanceMode == opt.0 ? .white : .white.opacity(0.6))
                                .padding(.horizontal, 13)
                                .padding(.vertical, 5)
                                .background {
                                    if appearanceMode == opt.0 {
                                        Capsule()
                                            .fill(Color.white.opacity(0.32))
                                            .matchedGeometryEffect(id: "appearancePill", in: appearanceNS)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(3)
                .glassEffect(.regular, in: Capsule())
                Text("深色会把天空场景、卡片和页面底色一起调暗；「按日出日落」按当前城市的日出日落自动切换，日落自动进入夜景。")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.75))
            }
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
}
