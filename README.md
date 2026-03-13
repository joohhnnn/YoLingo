# YoLingo

macOS 桌面端智能生词采集与复习工具。按住 fn 键点击屏幕上的任意英文单词，即可自动抓取、查词、入库，配合遗忘曲线算法在桌面悬浮卡片上定时复习。

## 核心功能

- **fn + 点击抓词** — 按住 fn 键点击任意应用中的英文单词，通过 OCR + Accessibility API 双通道提取文字
- **即时查词** — 抓词后弹出浮窗，显示音标、释义、AI 生成的例句
- **一键入库** — 点击「加入生词本」保存到本地 SQLite 数据库
- **桌面悬浮卡片** — 常驻桌面的半透明复习卡片，基于 SM-2 遗忘曲线算法推送待复习单词
- **深度复习** — 独立复习窗口，支持「认识 / 模糊 / 忘记」三级反馈
- **偏好设置** — AI 服务商切换（OpenAI / Gemini）、API Key 管理（Keychain 加密存储）、卡片位置与透明度调节、界面语言切换

## 技术栈

| 层级 | 技术 |
|------|------|
| 语言 | Swift 5.9+ |
| 平台 | macOS 13+ |
| UI | SwiftUI + NSPanel (悬浮窗) |
| 数据库 | GRDB (SQLite) |
| 复习算法 | SM-2 |
| 抓词 | Vision OCR + Accessibility API |
| 键盘监听 | CGEvent Tap + IOHIDManager + NSEvent |
| AI | OpenAI / Gemini API |
| 查词 | Free Dictionary API |

## 架构

```
App Layer        AppDelegate ← AppContainer (DI)
                      ↓ EventBus (Combine)
ViewModel Layer  CaptureOverlayVM · FloatingCardVM · ReviewVM · SettingsVM
                      ↓ @Published
View Layer       SwiftUI Views + NSPanel Windows
                      ↑
Service Layer    CaptureService · DictionaryService · AIService · SRSScheduler · SettingsService
                      ↑
Storage Layer    SQLiteWordRepository (GRDB)
```

**设计原则：** Protocol 隔离 · EventBus 解耦 · DI Container · 单向数据流

## 构建与运行

```bash
# 构建
swift build

# 运行
swift run

# 测试
swift test
```

需要在系统设置中授予以下权限：
1. **辅助功能** — 系统设置 → 隐私与安全性 → 辅助功能
2. **输入监控** — 系统设置 → 隐私与安全性 → 输入监控

## 许可证

CC BY-NC 4.0 — 允许自由使用和修改，禁止商业用途。
