# 里程志 iOS 移植版（未签名 IPA）

本项目根据 [Selwiro/MileNoteAndroid](https://github.com/Selwiro/MileNoteAndroid) 的领域模型与备份格式，用 SwiftUI 重写了 iOS 版本。目标是通过 GitHub Actions 在 macOS 运行器上构建出**未签名 IPA**，不需要 Apple Developer 账号。

## 一、用 GitHub Actions 构建 IPA

1. 在 GitHub 新建一个仓库（例如 `MileNoteiOS`）。
2. 把本目录下的**全部文件**（包含隐藏的 `.github` 目录）作为仓库根目录上传：

   ```bash
   cd MileNoteiOS
   git init
   git add .
   git commit -m "Initial iOS port"
   git remote add origin https://github.com/<你的用户名>/<你的仓库>.git
   git branch -M main
   git push -u origin main
   ```

3. 推送后进入仓库的 **Actions** 页面，等待 `Build unsigned IPA` 工作流自动运行；也可以点 **Run workflow** 手动触发。
4. 构建完成后，在工作流运行详情页底部 **Artifacts** 下载 `MileNote-unsigned-IPA`，解压得到：
   - `MileNote-unsigned.ipa`
   - `MileNote-unsigned.ipa.sha256`

## 二、未签名 IPA 的重要限制

- 未签名 IPA **无法直接安装到未越狱的 iPhone**。iOS 强制要求所有 App 签名。
- 如果要在自己的设备上安装，需要以下任一方式：
  - 用个人免费 Apple ID 签名后侧载（AltStore / 爱思助手 / Xcode 设备等）；
  - 加入 Apple Developer Program 后用 Ad Hoc / TestFlight 分发；
  - 在已越狱设备上安装。
- 本工作流只负责产出 IPA 文件，不涉及任何签名或分发操作。

## 三、本地 Mac 构建

需要 macOS + Xcode 15+ 与 Homebrew：

```bash
brew install xcodegen
xcodegen generate --spec project.yml
xcodebuild -project MileNote.xcodeproj -scheme MileNote \
  -configuration Release -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
  -derivedDataPath .build build
```

## 四、功能覆盖

已移植：

- 多车辆车库管理、当前车辆切换、主题切换
- 费用记录增删改查、分类筛选与搜索
- 满箱法 / 满电法油耗电耗计算（与 Android 版规则一致）
- 月度支出、费用构成、能耗趋势图表（SwiftUI 手绘）
- 保养提醒（里程 / 时间周期）、保养维修记录
- 与 Android / Web 版兼容的 `garage v2` JSON 备份导入导出
- WebDAV 上传 / 下载同步（URLSession Basic Auth）
- 内置演示数据

未移植（Android 专有能力）：

- 摄像头 OCR 识别加油小票（依赖 Tesseract4Android / JNI）
- CSV / XLS / XLSX / 钱迹导入向导、Excel 导出
- 在线油价查询、应用内更新检查、数据体检页
- 系统级快捷方式、通知、后台自动同步
- 分类 / 项目的自定义隐藏与显示名映射（备份字段会保留，但界面未实现）

## 五、数据兼容说明

- 备份 JSON 顶层为 `{"version":2,"activeId":...,"theme":...,"cars":[...]}`，与 Android 版一致。
- 支持读取 `version:1` 单车账本备份并迁移到车库。
- `nil` 字段在导出时会省略，与 Android 的 `explicitNulls = false` 行为一致。
- 密码以明文存入 `UserDefaults`，仅用于本地测试；如需正式使用请改用 Keychain。
