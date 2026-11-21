# 几何天气 · iOS 版

向开源安卓应用「几何天气（Geometric Weather）」致敬的 iOS 复刻：卡片式界面、免费无广告。

- 技术：SwiftUI（iOS 17+），工程由 XcodeGen 生成
- 数据源：[Open-Meteo](https://open-meteo.com/)（免费、免密钥），含空气质量接口
- 功能：定位天气、城市搜索与多城市切换、24 小时逐小时、15 日预报、空气质量、日出日落、紫外线
- 构建：推送到 main 后，GitHub Actions 在 macOS 构建机上打包**未签名 IPA**，并发布到 Releases
- 安装：下载 Releases 里的 `GeoWeather.ipa`，用 SideStore / AltStore 自签安装
