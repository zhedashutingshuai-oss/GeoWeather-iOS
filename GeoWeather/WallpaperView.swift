import SwiftUI
import Photos
import UIKit

/// 壁纸画布：所有尺寸按画布大小等比，预览与导出共用同一份排版
struct WallpaperArtwork: View {
    let size: CGSize
    let city: City
    let forecast: ForecastResponse?

    private var pair: (top: String, bottom: String) {
        if let c = forecast?.current {
            return WeatherCode.gradient(c.weather_code, isDay: c.is_day == 1)
        }
        return ("#3D7BDB", "#7FB2F0")
    }

    private var dateLine: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日 EEEE"
        return f.string(from: Date())
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: pair.top), Color(hex: pair.bottom)],
                           startPoint: .top, endPoint: .bottom)

            VStack(spacing: size.height * 0.012) {
                Text(city.name)
                    .font(.system(size: size.width * 0.082, weight: .semibold))
                Text(dateLine)
                    .font(.system(size: size.width * 0.042))
                    .foregroundStyle(.white.opacity(0.85))

                Spacer()

                if let f = forecast {
                    let c = f.current
                    if c.weather_code == 0 && c.is_day == 1 {
                        SunIcon(size: size.width * 0.44)
                    } else {
                        WeatherIcon(code: c.weather_code, isDay: c.is_day == 1, size: size.width * 0.44)
                    }
                    Text("\(Int(c.temperature_2m.rounded()))°")
                        .font(.system(size: size.width * 0.30, weight: .thin))
                    Text(WeatherCode.text(c.weather_code))
                        .font(.system(size: size.width * 0.062, weight: .medium))
                    if let hi = f.daily.temperature_2m_max.first, let lo = f.daily.temperature_2m_min.first {
                        Text("\(Int(lo.rounded()))° ~ \(Int(hi.rounded()))° · 体感 \(Int(c.apparent_temperature.rounded()))°")
                            .font(.system(size: size.width * 0.042))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                } else {
                    Text("天气加载中…")
                        .font(.system(size: size.width * 0.05))
                }

                Spacer()

                Text("几何天气 · Open-Meteo")
                    .font(.system(size: size.width * 0.034))
                    .foregroundStyle(.white.opacity(0.65))
                    .padding(.bottom, size.height * 0.045)
            }
            .foregroundStyle(.white)
            .padding(.top, size.height * 0.10)
            .frame(width: size.width, height: size.height)
        }
        .frame(width: size.width, height: size.height)
    }
}

struct WallpaperView: View {
    @EnvironmentObject var store: WeatherStore
    @State private var forecast: ForecastResponse?
    @State private var saveState = 0 // 0 待保存 1 保存中 2 已保存 3 失败

    private var city: City { store.selectedCity }

    private var previewSize: CGSize {
        let b = UIScreen.main.bounds
        let w: CGFloat = 208
        return CGSize(width: w, height: w * b.height / b.width)
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "#3D7BDB"), Color(hex: "#7FB2F0")],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("天气壁纸")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(.white)

                    WallpaperArtwork(size: previewSize, city: city, forecast: forecast)
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
                    .disabled(forecast == nil || saveState == 1)

                    if saveState == 3 {
                        Text("保存失败：请在系统设置里允许几何天气添加照片。")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                    }

                    Text("按当前选中城市的天气实时生成。iOS 不允许应用直接更换壁纸，保存后去相册或「设置 → 墙纸」里设为壁纸即可；想每天自动换，可以用快捷指令的「设定墙纸」动作选这张最新保存的图。")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.78))
                        .lineSpacing(3)
                }
                .padding(.horizontal, 16)
                .padding(.top, 56)
                .padding(.bottom, 110)
            }
        }
        .task(id: city.id) { await load() }
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
        guard let f = forecast else { return }
        saveState = 1
        let bounds = UIScreen.main.bounds
        let size = CGSize(width: bounds.width, height: bounds.height)
        let renderer = ImageRenderer(content: WallpaperArtwork(size: size, city: city, forecast: f))
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
