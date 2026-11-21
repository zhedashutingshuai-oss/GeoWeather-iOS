import SwiftUI
import UIKit

/// 中央气象台全国雷达拼图（2026-11-21 用户点选数据源①，要全国版方便出门看）
/// 数据页 https://www.nmc.cn/publish/radar/chinaall.html 内嵌全部帧的图片编码，
/// 图片在 image.nmc.cn 上、文件名带 UTC 时间戳、6 分钟一帧。
struct RadarFrame: Identifiable {
    let time: Date
    let url: URL
    var id: Date { time }
}

enum RadarTime {
    static func label(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.timeZone = TimeZone(identifier: "Asia/Shanghai")
        f.dateFormat = "M月d日 HH:mm"
        return f.string(from: d)
    }
}

enum RadarService {
    static func fetchFrames() async throws -> [RadarFrame] {
        var lastError: Error?
        for attempt in 0..<2 {
            if attempt > 0 { try? await Task.sleep(nanoseconds: 2_000_000_000) }
            do { return try await fetchOnce() } catch { lastError = error }
        }
        throw lastError ?? URLError(.unknown)
    }

    private static func fetchOnce() async throws -> [RadarFrame] {
        var req = URLRequest(url: URL(string: "https://www.nmc.cn/publish/radar/chinaall.html")!)
        req.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15",
                     forHTTPHeaderField: "User-Agent")
        let (data, _) = try await URLSession.shared.data(for: req)
        let html = String(decoding: data, as: UTF8.self)
        let regex = try NSRegularExpression(pattern: #"SEVP_AOC_RDCP_SLDAS3_ECREF_ACHN_L88_PI_(\d{14})000"#)
        let ns = html as NSString
        var stamps: [String] = []
        var seen = Set<String>()
        for m in regex.matches(in: html, range: NSRange(location: 0, length: ns.length)) {
            let s = ns.substring(with: m.range(at: 1))
            if seen.insert(s).inserted { stamps.append(s) }
        }
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(identifier: "UTC")
        df.dateFormat = "yyyyMMddHHmmss"
        let frames: [RadarFrame] = stamps.compactMap { s in
            guard let date = df.date(from: s) else { return nil }
            let yyyy = String(s.prefix(4))
            let mm = String(s.dropFirst(4).prefix(2))
            let dd = String(s.dropFirst(6).prefix(2))
            guard let url = URL(string: "https://image.nmc.cn/product/\(yyyy)/\(mm)/\(dd)/RDCP/medium/SEVP_AOC_RDCP_SLDAS3_ECREF_ACHN_L88_PI_\(s)000.PNG") else { return nil }
            return RadarFrame(time: date, url: url)
        }
        // 最近 24 帧 ≈ 2.4 小时，够看雨带移动，加载量也可控
        return Array(frames.sorted { $0.time < $1.time }.suffix(24))
    }

    static func loadImage(_ url: URL) async -> UIImage? {
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        return UIImage(data: data)
    }
}

struct RadarImageView: View {
    let url: URL
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable()
            } else {
                Rectangle().fill(.white.opacity(0.08))
                    .overlay(ProgressView().tint(.white))
            }
        }
        .task(id: url) { image = await RadarService.loadImage(url) }
    }
}

/// 可捏合缩放的图片容器（UIScrollView 经典实现）
struct ZoomableImageView: UIViewRepresentable {
    let image: UIImage?

    func makeUIView(context: Context) -> UIScrollView {
        let scroll = UIScrollView()
        scroll.minimumZoomScale = 1
        scroll.maximumZoomScale = 4
        scroll.delegate = context.coordinator
        scroll.backgroundColor = .clear
        scroll.showsVerticalScrollIndicator = false
        scroll.showsHorizontalScrollIndicator = false
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(iv)
        NSLayoutConstraint.activate([
            iv.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            iv.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            iv.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            iv.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            iv.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor),
            iv.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor),
        ])
        context.coordinator.imageView = iv
        return scroll
    }

    func updateUIView(_ scroll: UIScrollView, context: Context) {
        context.coordinator.imageView?.image = image
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        var imageView: UIImageView?
        func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }
    }
}

struct RadarFullView: View {
    let frames: [RadarFrame]
    @Environment(\.dismiss) private var dismiss
    @State private var images: [Int: UIImage] = [:]
    @State private var index: Int
    @State private var playing = true

    init(frames: [RadarFrame]) {
        self.frames = frames
        _index = State(initialValue: max(0, frames.count - 1))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 12) {
                HStack {
                    Text("全国雷达拼图")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
                ZoomableImageView(image: images[index])
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                if frames.indices.contains(index) {
                    Text(RadarTime.label(frames[index].time) + "（北京时间）")
                        .font(.subheadline)
                        .foregroundStyle(.white)
                }
                HStack(spacing: 14) {
                    Button {
                        playing.toggle()
                    } label: {
                        Image(systemName: playing ? "pause.fill" : "play.fill")
                            .font(.title3)
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                    }
                    .buttonStyle(.glass)
                    Slider(value: Binding(
                        get: { Double(index) },
                        set: { index = Int($0.rounded()); playing = false }
                    ), in: 0...Double(max(1, frames.count - 1)), step: 1)
                    .tint(.white)
                }
                Text("数据源：中央气象台 · 每 6 分钟一帧 · 已加载 \(images.count)/\(frames.count) 帧 · 双指可放大")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding()
        }
        .task { await preload() }
        .task(id: playing) { await runAnimation() }
    }

    private func preload() async {
        for i in frames.indices where images[i] == nil {
            images[i] = await RadarService.loadImage(frames[i].url)
        }
    }

    private func runAnimation() async {
        guard playing else { return }
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 700_000_000)
            if Task.isCancelled || !playing { break }
            var next = index + 1
            if next >= frames.count { next = 0 }
            if images[next] != nil { index = next }
        }
    }
}
