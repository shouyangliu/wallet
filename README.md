<p align="center">
  <img src="mm_facetoface_collect_qrcode_1778429391872.png" width="120" alt="logo">
</p>

<h1 align="center">yl记账</h1>

<p align="center">
  <b>简单 · 轻量 · 好用的个人记账应用</b>
  <br>
  <sub>用 Flutter 构建，随时随地记录你的每一笔账</sub>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.7+-02569B?logo=flutter" alt="Flutter">
  <img src="https://img.shields.io/badge/version-1.1.0-blue" alt="version">
  <img src="https://img.shields.io/badge/license-MIT-green" alt="license">
</p>

---

## ✨ 功能一览

| 功能 | 说明 |
|------|------|
| 🏦 **多账户管理** | 用颜色和 emoji 自定义你的账户（现金、银行卡、信用卡……） |
| 📝 **收支记录** | 快速记账，支持分类、备注、时间，支出收入一目了然 |
| 📊 **图表统计** | 饼图直观展示各类消费占比，帮你管好钱袋子 |
| 🔍 **筛选搜索** | 按账户、类别、日期范围筛选，快速找到目标记录 |
| 📂 **CSV 导入/导出** | 支持 CSV 格式备份数据，也可从其他应用迁移 |
| ☁️ **云端同步** | 接入 Supabase，登录后数据自动同步，换机不丢数据 |
| 🌙 **深色模式** | 支持明暗主题一键切换，夜间使用更舒适 |
| 🎨 **自定义主题** | 自由选择主题色和饱和度，打造你的专属风格 |

---

## 🚀 快速开始

### 前置要求

- Flutter SDK ^3.7.0
- Dart SDK ^3.7.0

### 安装

```bash
# 克隆仓库
git clone https://github.com/your-username/yl_wallet.git
cd yl_wallet

# 安装依赖
flutter pub get

# 运行（支持所有 Flutter 平台）
flutter run
```

### 构建

```bash
# Android APK
flutter build apk --release

# iOS
flutter build ios --release

# Web
flutter build web --release
```

---

## ☁️ 启用云端同步

应用默认纯本地运行，开箱即用。如需云端同步：

1. 在 [supabase.com](https://supabase.com) 注册并创建项目
2. 在 **SQL Editor** 中执行 [`supabase_setup.sql`](supabase_setup.sql) 建表
3. 复制 `lib/config.example.dart` 为 `lib/config.dart`，填入你的 Supabase URL 和 anon key
4. 将 `cloudEnabled` 改为 `true`

```dart
class AppConfig {
  static const String supabaseUrl = 'https://你的项目.supabase.co';
  static const String supabaseAnonKey = '你的anon-public-key';
  static const bool cloudEnabled = true;
}
```

> ⚠️ `config.dart` 已加入 `.gitignore`，不会提交到仓库

---

## 🎯 使用场景

- **日常记账** — 随手记下每笔开销，月底看看钱都花哪了
- **多账户管理** — 同时管理现金、储蓄卡、信用卡、花呗等多个账户
- **预算规划** — 通过图表分析消费结构，合理规划下月预算
- **数据迁移** — 通过 CSV 导入/导出，轻松换机或备份

---

## 🛠 技术栈

| | |
|---|---|
| **框架** | [Flutter](https://flutter.dev) — 跨平台 UI 框架 |
| **语言** | [Dart](https://dart.dev) |
| **本地存储** | [shared_preferences](https://pub.dev/packages/shared_preferences) |
| **云端数据库** | [Supabase](https://supabase.com) + [supabase_flutter](https://pub.dev/packages/supabase_flutter) |
| **图表** | [fl_chart](https://pub.dev/packages/fl_chart) |
| **日期处理** | [intl](https://pub.dev/packages/intl) |
| **文件选择** | [file_picker](https://pub.dev/packages/file_picker) |

---

## 📁 项目结构

```
lib/
├── main.dart                   # 主入口 & 全部 UI 逻辑
├── config.dart                 # Supabase 配置（已 gitignore）
├── config.example.dart         # 配置模板
├── models/
│   ├── account.dart            # 账户模型
│   ├── transaction.dart        # 交易记录模型
│   ├── category.dart           # 分类模型
│   └── budget.dart             # 预算模型
├── services/
│   └── database_service.dart   # 数据服务（本地 + 云端自动同步）
└── pages/
    └── auth_page.dart          # 登录/注册页面
```

---

## 🤝 贡献

欢迎提交 Issue 和 PR！如果你有好的想法或发现 bug，欢迎一起让这个应用变得更好。

---

## ☕ 支持项目

如果这个应用对你的生活有帮助，欢迎请我喝杯咖啡，支持持续开发 ❤️

<p align="center">
  <img src="mm_facetoface_collect_qrcode_1778429391872.png" width="250" alt="微信收款码">
</p>
<p align="center"><b>微信扫一扫，请我喝咖啡 ☕</b></p>

---

<p align="center">
  Made with ❤️ and Flutter
  <br>
  <sub>yl记账 — 简单记账，认真生活</sub>
</p>
