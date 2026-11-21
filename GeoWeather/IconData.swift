// IconData.swift — 原版几何天气图标（内嵌数据 + 解码缓存）
// 图标源文件存档在项目 icon-source/ 目录；因仓库推送通道只收文本，图标以 base64 内嵌。
import UIKit

enum WeatherIconData {
    static let all: [String: String] = chunk1
        .merging(chunk2) { a, _ in a }
        .merging(chunk3) { a, _ in a }

    private static var cache: [String: UIImage] = [:]

    static func image(named name: String) -> UIImage? {
        if let img = cache[name] { return img }
        guard let b64 = all[name],
              let data = Data(base64Encoded: b64),
              let img = UIImage(data: data) else { return nil }
        cache[name] = img
        return img
    }
}
