# Straight-Guy-Chat-Tool - AI聊天分析与回复助手

一款基于 Flutter 开发的 Android App，通过 AI 大模型+知识库，分析聊天截图内容，帮助用户读懂对方心理、对方意图、识别沟通风险、生成高质量回复建议。

## ✨ v2.0 更新亮点

### 🔌 自定义 API 支持
- **多服务商预设**：内置豆包、OpenAI、DeepSeek、通义千问、月之暗面 Kimi、智谱 GLM 六大主流 API 服务商，一键切换
- **自定义端点**：支持填写任意 OpenAI 兼容格式的 API 地址，适配任意第三方中转服务
- **视觉能力标识**：每个服务商标注是否支持图片输入，避免选错模型
- **自动填充**：切换服务商时自动填充默认 endpoint 和模型名称
- **灵活配置**：API Key、模型名称、API 地址均可独立编辑

### 🎨 UI 全面优化
- **深色渐变主题**：全新午夜深蓝色板（#0A0E21），配合紫蓝/紫粉/青蓝多套渐变方案
- **玻璃态卡片**：cardGlassGradient 玻璃拟态效果，半透明渐变+微光边框
- **发光阴影**：accentGlow 光晕效果，强调元素自带辉光
- **动画交互**：场景切换/按钮点击带 AnimatedContainer 过渡动画，分析中状态脉冲呼吸效果
- **首页 Hero 区**：新增状态芯片（API 配置状态+当前服务商），一目了然
- **输入框优化**：带前缀图标的输入框，聚焦时高亮边框
- **启动页优化**：渐变背景+Logo+加载动画

## 功能特点

📷 **截图AI分析**：一键截图，AI自动分析对方心理状态、真实意图、潜在风险
💬 **智能回复建议**：根据分析结果，给出2-3条符合价值观的回复建议
🪟 **悬浮窗模式**：边聊边看，无需切换APP，在微信/QQ等任何APP上方直接分析
🌍 **多场景支持**：职场、亲密关系、家庭、社交四大场景切换
⚖️ **价值观约束**：自定义处事底线和各场景沟通原则，让AI回复更贴合你的风格

## 技术栈

| 项目 | 说明 |
|------|------|
| 框架 | Flutter 3.12+ |
| 语言 | Dart / Kotlin |
| AI模型 | 任意 OpenAI 兼容格式 API（豆包/OpenAI/DeepSeek/通义千问/Kimi/GLM/自定义） |
| 原生能力 | Android 悬浮窗、MediaProjection 截图 |

## 快速开始

### 环境要求

- Flutter 3.12+
- Android SDK 26+ (Android 8.0+)

### 安装步骤

```bash
# 1. 克隆仓库
git clone https://github.com/ffly12551-code/Straight-Guy-Chat-Tool-chat_mind.git
cd Straight-Guy-Chat-Tool-chat_mind

# 2. 安装依赖
flutter pub get

# 3. 运行
flutter run
```

### API 配置

1. 打开 APP → 进入**设置**页面
2. 在「API 配置」区域选择服务商（豆包/OpenAI/DeepSeek/通义千问/Kimi/GLM/自定义）
3. 填入对应平台的 **API Key**
4. 确认/修改**模型名称**和**API 地址**（预设服务商会自动填充）
5. 点击「保存设置」

> 💡 如果使用「自定义 API」，填写任意 OpenAI 兼容格式的 endpoint 即可。

## 支持的 API 服务商

| 服务商 | 默认模型 | 支持图片 | 说明 |
|--------|----------|----------|------|
| 火山引擎豆包 | doubao-1.5-vision-pro-32k | ✅ | 字节跳动，国内直连速度快 |
| OpenAI | gpt-4o | ✅ | GPT-4o 多模态，需海外网络 |
| DeepSeek | deepseek-chat | ❌ | 性价比极高（不支持图片） |
| 通义千问 | qwen-vl-max | ✅ | 阿里云视觉模型 |
| 月之暗面 Kimi | moonshot-v1-8k | ❌ | 长文本能力强（不支持图片） |
| 智谱 GLM | glm-4v | ✅ | 智谱 AI 视觉模型 |
| 自定义 | 用户填写 | ✅ | 任意 OpenAI 兼容格式 |

## 使用说明

### 方式一：APP内分析
1. 打开 APP
2. 选择场景（职场/亲密关系/家庭/社交）
3. 点击「从相册选择」或截图
4. 查看AI分析结果

### 方式二：悬浮窗模式（推荐）
1. 打开 APP
2. 点击「打开悬浮窗」，授予权限
3. 返回微信/QQ等聊天APP
4. 点击悬浮球 → 框选聊天区域 → 查看分析结果

## 项目结构

```
Straight-Guy-Chat-Tool-chat_mind/
├── lib/
│   ├── models/
│   │   ├── analysis_result.dart      # 分析结果数据模型
│   │   └── user_settings.dart        # 用户设置数据模型
│   ├── pages/
│   │   ├── home_page.dart            # 主页面 + 分析结果弹窗
│   │   ├── settings_page.dart        # 设置页（API服务商选择+配置）
│   │   ├── privacy_page.dart         # 隐私声明页
│   │   └── values_editor_page.dart   # 价值观编辑器
│   ├── services/
│   │   ├── ai_service.dart           # AI分析服务（多API适配）
│   │   ├── screenshot_service.dart   # 截图服务
│   │   ├── float_window_service.dart # 悬浮窗服务
│   │   ├── storage_service.dart      # 本地存储服务
│   │   └── permission_service.dart   # 权限服务
│   ├── utils/
│   │   ├── constants.dart            # 常量定义（API服务商预设）
│   │   ├── theme.dart                # 主题系统（深色渐变）
│   │   └── toast.dart                # Toast 提示
│   ├── app.dart                      # App 入口与状态管理
│   └── main.dart                     # main 函数
├── android/                           # Android 原生代码
├── pubspec.yaml                       # 依赖配置
└── README.md                          # 项目说明
```

## 核心文件说明

| 文件 | 作用 |
|------|------|
| `lib/utils/constants.dart` | API 服务商预设列表、场景定义、价值观模板 |
| `lib/services/ai_service.dart` | AI 分析服务，支持任意 OpenAI 兼容 API，封装请求/解析逻辑 |
| `lib/services/storage_service.dart` | 本地存储，管理 API Key / Base URL / 服务商 / 模型等配置 |
| `lib/utils/theme.dart` | 深色渐变主题系统，含多套渐变方案和玻璃态效果 |
| `lib/pages/settings_page.dart` | 设置页面，含 API 服务商选择器和配置表单 |
| `lib/pages/home_page.dart` | 主页面，场景切换、截图分析入口、结果展示弹窗 |

## 开源协议

MIT License

## 贡献

欢迎提交 Issue 和 Pull Request！

## 致谢

- 火山引擎豆包大模型
- OpenAI / DeepSeek / 通义千问 / Kimi / 智谱 GLM
- Flutter
