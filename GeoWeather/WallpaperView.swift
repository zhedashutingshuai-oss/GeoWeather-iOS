import SwiftUI
import Photos
import UIKit

/// 一个可选的壁纸场景
struct SceneOption: Identifiable {
    let id: String
    let name: String
    let code: Int
    let isDay: Bool
}

struct WallpaperView: View {
    @EnvironmentObject var store: WeatherStore
    @State private var forecast: ForecastResponse?
    @State private var selectedID: String?
    @State private var saveState = 0 // 0 待保存 1 保存中 2 已保存 3 失败

    private let options: [SceneOption] = [
        .init(id: "clear-day", name: "晴天", code: 0, isDay: true),
        .init(id: "partly-day", name: "多云", code: 2, isDay: true),
        .init(id: "overcast", name: "阴天", code: 3, isDay: true),
        .init(id: "rain-light", name: "小雨", code: 61, isDay: true),
        .init(id: "rain-heavy", name: "大雨", code: 65, isDay: true),
        .init(id: "thunder", name: "雷雨", code: 95, isDay: true),
        .init(id: "snow", name: "雪天", code: 73, isDay: true),
        .init(id: "fog", name: "雾天", code: 45, isDay: true),
        .init(id: "clear-night", name: "晴夜", code: 0, isDay: false),
        .init(id: "partly-night", name: "多云夜", code: 2, isDay: false),
    ]

    private var city: City { store.selectedCity }

    /// 当前真实天气对应的场景 id（默认选中并打「当前」标）
    private var currentOptionID: String? {
        guard let c = forecast?.current else { return nil }
        switch SceneKind(code: c.weather_code) {
        case .clear: return c.is_day == 1 ? "clear-day" : "clear-night"
        case .partly: return c.is_day == 1 ? "partly-day" : "partly-night"
        case .cloudy, .overcast: return "overcast"
        case .fog: return "fog"
        case .drizzle: return "rain-light"
        case .rain: return c.precipitation >= 2.5 ? "rain-heavy" : "rain-light"
        case .heavyRain: return "rain-heavy"
        case .thunder, .hail: return "thunder"
        case .snow, .heavySnow: return "snow"
        }
    }

    private var selected: SceneOption {
        options.first { $0.id == (selectedID ?? currentOptionID ?? "clear-day") } ?? options[0]
    }

    private var previewSize: CGSize {
        let b = UIScreen.main.bounds
        let w: CGFloat = 218
        return CGSize(width: w, height: w * b.height / b.width)
    }

    var body: some View {
        ZStack {
            PageGradient()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("天气壁纸")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(.white)

                    canvas(size: previewSize, option: selected)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .shadow(color: .black.opacity(0.3), radius: 16, y: 8)
                        .frame(maxWidth: .infinity)

                    Button {
                        save()
                    } label: {
                        Label(saveState == 2 ? "已保存到相册" : (saveState == 1 ? "保存中…" : "保存到相册"),
                              systemImage: saveState == 2 ? "checkmark" : "square.and.arrow.down")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.glass)
                    .foregroundStyle(.white)
                    .disabled(saveState == 1)

                    if saveState == 3 {
                        Text("保存失败：请在系统设置里允许司天添加照片。")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                    }

                    Text("全部天气")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.top, 4)

                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10),
                                        GridItem(.flexible(), spacing: 10),
                                        GridItem(.flexible(), spacing: 10)], spacing: 14) {
                        ForEach(options) { option in
                            Button {
                                selectedID = option.id
                                saveState = 0
                            } label: {
                                VStack(spacing: 6) {
                                    ZStack(alignment: .topLeading) {
                                        WeatherSceneView(code: option.code, isDay: option.isDay, animated: false)
                                            .frame(height: 128)
                                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                            .overlay {
                                                if selected.id == option.id {
                                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                        .stroke(Color.white, lineWidth: 2.5)
                                                }
                                            }
                                        if currentOptionID == option.id {
                                            Text("当前")
                                                .font(.caption2.weight(.bold))
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Capsule().fill(Color(hex: "#FF9435")))
                                                .foregroundStyle(.white)
                                                .padding(6)
                                        }
                                    }
                                    Text(option.name)
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(selected.id == option.id ? .white : .white.opacity(0.75))
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Text("画面跟着天气走：晴天蓝天白云、雨天按雨量落雨滴、阴天灰调、雪天飘雪、夜里有星星月亮。iOS 不允许应用直接更换壁纸，保存后去相册或「设置 → 墙纸」里设为壁纸即可。")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.78))
                        .lineSpacing(3)
                }
                .padding(.horizontal, 16)
                .padding(.top, 56)
                .padding(.bottom, 28)
            }
        }
        .task(id: city.id) { await load() }
    }

    /// 壁纸画布：纯场景，不带任何文字（城市/温度/天气字样全去掉）
    private func canvas(size: CGSize, option: SceneOption) -> some View {
        WeatherSceneView(code: option.code, isDay: option.isDay, animated: false)
            .frame(width: size.width, height: size.height)
    }

    private func load() async {
        if let cached = ForecastCache.load(for: city) {
            forecast = cached.forecast
        }
        if let f = try? await WeatherService.fetchForecast(for: city) {
            forecast = f
            ForecastCache.save(f, for: city)
        }
    }

    private func save() {
        saveState = 1
        let bounds = UIScreen.main.bounds
        let size = CGSize(width: bounds.width, height: bounds.height)
        let renderer = ImageRenderer(content: canvas(size: size, option: selected))
        renderer.scale = UIScreen.main.scale
        guard let image = renderer.uiImage else {
            saveState = 3
            return
        }
        PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        } completionHandler: { ok, _ in
            DispatchQueue.main.async { saveState = ok ? 2 : 3 }
        }
    }
}
