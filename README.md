# TravelBuddy（旅行计划）

一个 iOS 17+ 的中文原生 SwiftUI 旅行规划 App。界面使用奶油色背景、柔和马卡龙配色和原创“小桃”旅行猪角色；数据由 SwiftData 保存在本机，核心功能无需账号和网络。

## 功能

- 多旅行创建、编辑、封面照片与自动日期生成；目的地不设白名单，可记录世界上任意城市、国家或景点
- 在新建旅行时直接按目的地搜索代表性横图并设为封面，网络图片会下载到本机供离线查看
- 可在“我的 → OpenAI 旅行封面”保存个人 API Key；有 Key 时新旅程优先生成统一小桃画风封面并显示进度，缺少 Key 或生成失败时自动使用默认封面
- 按天列表 / 完整时间线、月历与旅行日期高亮
- 上午、下午、晚上、饮食活动的新增、编辑、完成和删除
- 餐食计划、MapKit 地点搜索与地图标记
- PhotosUI 本地照片导入、离线文件存储
- Unsplash 高质量旅行摄影搜索；未配置 Key 时自动回退到维基百科的自由许可代表图
- 收藏地点与餐厅、首次启动示例数据
- GitHub Actions 自动测试、构建并产出 Sideloadly 可重签名的未签名 IPA

## Windows + GitHub 构建 IPA

1. 将仓库推送到 GitHub，打开 **Actions → 构建 TravelBuddy IPA → Run workflow**。
2. 构建成功后，在该次运行的 **Artifacts** 下载 `TravelBuddy-unsigned-IPA`。
3. 解压得到 `TravelBuddy-unsigned.ipa`，在 Windows 打开 Sideloadly，连接 iPhone 后拖入 IPA。
4. 输入 Apple ID，让 Sideloadly 使用你的个人开发证书签名并安装。
5. iPhone 首次侧载前需开启“设置 → 隐私与安全性 → 开发者模式”，并在设备管理中信任对应账号。

免费 Apple ID 的侧载 App 通常需要每 7 天重新签名安装；具体限制由 Apple 当前政策决定。GitHub 生成的是未签名 IPA，Apple ID 只在你的 Sideloadly 本机使用，不应放进 GitHub Secrets。

## 在 Mac / Xcode 打开

安装 [XcodeGen](https://github.com/yonaskolb/XcodeGen) 后在项目根目录运行：

```sh
xcodegen generate
open TravelBuddy.xcodeproj
```

在 Target → Signing & Capabilities 中选择你的 Team，并把 `com.example.TravelBuddy` 改成自己的唯一 Bundle Identifier，然后选择真机运行。

## 在线图片配置

在 Target 的 Info 配置中将 `UNSPLASH_ACCESS_KEY` 设为你的 Unsplash Access Key。配置后，目的地封面和相册搜索会优先使用相关度排序的横向旅行摄影；选择图片时会调用 Unsplash 要求的下载统计端点，并展示摄影师署名。Key 为空时自动改用维基百科代表图，也继续支持本地照片。不要把私密 Key 提交到公开仓库。

OpenAI 封面无需修改工程文件：在 App 的“我的 → OpenAI 旅行封面”输入 API Key，Key 仅存储在当前 iPhone 的 Keychain，不会进入 SwiftData、Git 或 GitHub Actions。新建旅程且没有手动选择封面时，App 会调用 OpenAI Image API，以内置原创小桃封面作为风格参考生成目的地图片。API 调用可能产生费用，并受 OpenAI 账户用量与模型访问权限限制。

## iPhone 全屏显示

工程启用了系统生成的 `UILaunchScreen` 和现代 SwiftUI Scene Manifest，避免新款 iPhone 进入旧式兼容分辨率。升级此修复版本时，请先从 iPhone 删除旧版 TravelBuddy，再用 Sideloadly 安装新 IPA；iOS 会缓存旧 App 的启动画面与尺寸信息，直接覆盖安装可能仍显示旧黑边。

## 说明

当前开发环境是 Windows，不能在本机运行 Xcode 或真机测试；项目由 GitHub macOS Runner 执行实际 Xcode 编译与测试。App 中的原创“小桃”与旅行封面均位于 Asset Catalog。

