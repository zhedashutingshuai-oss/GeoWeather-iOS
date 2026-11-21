import SwiftUI

struct AboutView: View {
    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label).foregroundStyle(.white.opacity(0.75))
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .foregroundStyle(.white)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "#3D7BDB"), Color(hex: "#7FB2F0")],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("关于")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(.white)

                    VStack(spacing: 4) {
                        Text("几何天气")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(.white)
                        Text("当前版本")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.8))
                        Text("1.1")
                            .font(.system(size: 42, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)

                    Card(title: "信息") {
                        VStack(spacing: 8) {
                            infoRow("数据来源", "Open-Meteo（免费开放气象数据）")
                            infoRow("天气图标", "原版几何天气图标")
                            infoRow("原作", "Geometric Weather · WangDaYeeeeee")
                            infoRow("说明", "iOS 复刻练习作品，数据仅供参考")
                        }
                    }

                    Card(title: "功能") {
                        VStack(spacing: 8) {
                            infoRow("预报", "15 日 · 逐小时 · 空气质量")
                            infoRow("壁纸", "按当前天气生成，可保存到相册")
                            infoRow("工具", "指南针 · 坐标 · 帧率演示")
                            infoRow("小组件", "桌面组件（需 SideStore 直装）")
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 56)
                .padding(.bottom, 110)
            }
        }
    }
}
