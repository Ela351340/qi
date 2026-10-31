# 交接文档

> 给接手的人：读完这一份，就能跑起来、改下去、发出去。
> 最后更新：v1.5.1

---

## 1. 这是什么

**栖（Qi）**：安卓端的 AI 陪伴聊天应用。

- 她和常见 AI 助手的区别：**人格可编辑、记忆外置成文件、会自己挑表情、会主动找你**
- 数据全部留在本机；模型可以是云 API，也可以是自己的 Ollama
- 单机应用，没有服务端、没有账号体系

| 项 | 值 |
|---|---|
| 应用名 | 栖 |
| 包名 | `app.qi.chat` |
| 版本 | 1.5.1（versionCode 33） |
| 技术栈 | Flutter 3.47 / Dart 3.13，仅 Android |
| 许可证 | MIT |
| 仓库 | https://github.com/Ela351340/qi |
| 本地路径 | `D:\AI\An\aichat\app` |

---

## 2. 现在能用的功能

**聊天**
- QQ 风格单聊，流式逐字输出，思考内容自动隐藏
- 时间分隔、撤回（变系统提示）、删除、复制
- 长按消息弹出**贴着气泡的小菜单**（带指向三角）
- 图片 / 视频 / 文件发送；图片可全屏查看
- 输入框多行自适应（1–5 行），回车换行、按钮发送

**她**
- 人格档案：名字、一句话、性格标签、开场白、人设正文，全部可改
- **联网补全人格**：给个关键词，搜资料 → 生成结构化人设 → 回填
- **外置记忆**：`facts.md` / `episodes.md` / `profile.md`，一行一条，可直接编辑
- **自动整理记忆**：每 6 条消息后台提炼一次，去重
- **主动开口**：回前台时检查，超时且不在 0–10 点、不在免打扰时段则说一句
- **表情**：她自己按 `[s:标签]` 挑；你可导入自己的表情包

**外观**
- 浅色 / 深色（深色纯黑），主题可切
- 8 套配色方案 + 23 种气泡色 + 背景色/图
- 头像裁剪（完整模式：不裁边、留白透明）

**模型接入**
- 任意 OpenAI 兼容接口；DeepSeek / 通义 / Ollama 一键预设
- 连接测试：显示真实 HTTP 状态码和返回原文
- API Key 存 Android Keystore，不落明文、不进备份

---

## 3. 代码地图

```
app/lib
├── main.dart                 入口：主题 + 首页
├── models/                   纯数据
│   ├── app_settings.dart     设置（含 providers 列表）
│   ├── chat_message.dart     消息（文本/表情/附件）
│   ├── conversation.dart     会话
│   ├── memory_item.dart      记忆条目
│   └── sticker.dart          表情包结构
├── core/
│   ├── config/app_config.dart        内置 3 个默认 provider + 默认提示词
│   ├── llm/
│   │   ├── llm_client.dart           流式请求、错误中文映射
│   │   ├── sse_parser.dart           分片安全的 SSE 解析
│   │   ├── llm_provider.dart         provider 模型 + URL 归一化
│   │   ├── api_key_store.dart        Keystore 存 Key
│   │   └── sticker_tag.dart          [s:标签] 提取/剥离 + 概率闸门
│   ├── storage/
│   │   ├── settings_store.dart       设置读写（Key 走 Keystore）
│   │   └── conversation_store.dart   会话读写
│   ├── memory/
│   │   ├── memory_store.dart         markdown 记忆文件
│   │   └── memory_prompt.dart        记忆注入 + 提炼提示词 + 解析
│   ├── stickers/
│   │   ├── sticker_catalog.dart      两套表情包加载
│   │   ├── user_sticker_store.dart   用户导入的表情（文件）
│   │   └── ai_sticker_store.dart     给"她"加的表情（文件 + 标签索引）
│   ├── notify/                       通知 + 免打扰判定
│   ├── voice/tts_service.dart        系统 TTS（含音色选择）
│   ├── settings/feature_prefs.dart   语音/主动/自动记忆等开关
│   ├── web/web_search.dart           DuckDuckGo 抓取（供人格补全用）
│   └── theme/                        主题控制 + 配色方案
├── features/
│   ├── home/        首页（她 + 最近会话 + 开始新对话）
│   ├── chat/        聊天页（核心，1300+ 行）
│   ├── settings/    设置页（最大文件，1600+ 行）
│   ├── persona/     人格卡片页
│   ├── memory/      记忆页
│   ├── stickers/    表情面板（4 个 tab）
│   └── avatar/      头像裁剪
├── theme/app_theme.dart      AppColors / AppMetrics / AppText
└── shared/                   顶栏状态栏填充、翻页动效
```

**改代码前先知道的三件事**

1. **颜色不要写死**：一律从 `AppColors`（ThemeExtension）取，否则深色模式会出问题
2. **`chat_page.dart` 是核心**：发送、流式、附件、表情、菜单、主动聊天都在里面
3. **`settings_page.dart` 很长**：按 `_section` 分段搜，比通读快

---

## 4. 构建

### 环境

| 依赖 | 版本/说明 |
|---|---|
| Flutter | 3.47+ |
| JDK | 17 |
| Android SDK | 36（compileSdk 36，minSdk 24） |
| **NDK** | 28.2.13676358（`jni` 依赖需要） |
| **CMake** | 3.22.1（同上） |
| **platform android-34** | `file_picker` 需要 |

首次构建前：

```bash
sdkmanager "ndk;28.2.13676358" "cmake;3.22.1" "platforms;android-34"
```

### 命令

```bash
cd app
flutter pub get
flutter analyze          # 必须 0 issue
flutter test             # 必须全绿
flutter build apk --release
```

产物：`build/app/outputs/flutter-apk/app-release.apk`

### 国内网络的三个坑

1. **Gradle 分发包慢** → `gradle-wrapper.properties` 换成腾讯镜像
2. **Maven 依赖慢** → 在 `~/.gradle/init.gradle.kts` 加阿里云镜像（见下）
3. **Flutter 资源慢** → 设 `PUB_HOSTED_URL` / `FLUTTER_STORAGE_BASE_URL` 为国内镜像

```kotlin
// ~/.gradle/init.gradle.kts
val mirrors = listOf(
  "https://maven.aliyun.com/repository/google",
  "https://maven.aliyun.com/repository/public",
  "https://maven.aliyun.com/repository/gradle-plugin",
)
beforeSettings {
  pluginManagement.repositories { mirrors.forEach { maven { url = uri(it) } } }
  dependencyResolutionManagement.repositories { mirrors.forEach { maven { url = uri(it) } } }
}
```

> 注意：**不要同时在 `settings.gradle.kts` 里加仓库**，两边都配会触发
> "prefer settings repositories over project repositories" 报错。

### 签名

`android/app/build.gradle.kts` 里 debug 签名指向**工程内**的 `debug.keystore`
（已 gitignore），不依赖 `C:\Users\<你>\.android`——这样换机器也能直接编。

发布到应用商店前换成正式签名，并把 `signingConfig` 改掉。

---

## 5. 数据都存在哪

| 数据 | 位置 | 加密 |
|---|---|---|
| 设置、会话 | SharedPreferences（再落到应用私有目录） | 否 |
| 记忆 | `<应用文档目录>/memory/*.md` | 否，明文可编辑 |
| 附件副本 | `<应用文档目录>/attachments/` | 否 |
| 用户表情 | `<应用文档目录>/stickers/user/` | 否 |
| 她的自定义表情 | `<应用文档目录>/stickers/ai_user/` + `index.json` | 否 |
| **API Key** | **Android Keystore** | **是** |

**备份已关闭**（`allowBackup="false"`），Key 不会进云备份。

**为什么附件要复制副本**：原文件在相册被删后，聊天记录会裂图。

---

## 6. 关键设计决策（改之前先看，别踩回去）

| 决策 | 原因 |
|---|---|
| **不做 GUI 自动化**（不去点豆包/B站/抖音） | ① 无障碍服务读不到 WebView 里的回复，功能本身做不完整 ② 应用商店明文禁止 ③ 权限过重，和"本地优先"的定位冲突 |
| **深色用纯黑** | 用户明确要求；层次靠 1px 描边而不是色差 |
| **API Key 进 Keystore** | prefs 是明文 XML，root/备份/调试都能读到 |
| **头像/背景字节要缓存** | `Uint8List.fromList` 每次产生新对象 → MemoryImage 缓存键失效 → **每次重建重新解码**，长列表直接卡死 |
| **输入框按需 setState** | 原来每敲一个字重建整页；改成只在"有无文字"翻转时重建 |
| **消息列表包 RepaintBoundary** | 键盘弹出只重排不重绘 |
| **长按菜单用 Overlay + 手动移除** | 必须随页面一起销毁（`PopScope` + `deactivate` + `dispose` 三处兜底），否则退出聊天后菜单还挂在别的界面上 |
| **表情用 `[s:标签]` 协议** | 复用 AstrBot 社区做法；标签对不上就静默丢弃，不会把标记漏给用户 |
| **包名 `app.qi.chat`** | 上架后不能改，早期定的 |

---

## 7. 测试

```bash
flutter test                 # 102 个用例
flutter test --update-goldens  # 改界面后重生成截图
```

| 类型 | 文件 | 说明 |
|---|---|---|
| Golden 截图 | `golden_test.dart` | 首页/聊天/深色/面板/抽屉/设置/人格/记忆 |
| 流式 | `streaming_test.dart` | 逐字上屏、思考隐藏、报错重试 |
| 表情 | `ai_sticker_test.dart` | 标签命中、概率闸门、空气泡 |
| 记忆 | `memory_test.dart` | 注入截断、提炼解析 |
| 其它 | settings / catalog / sse / quiet_hours / stress（2000 条消息） | — |

**测试环境注意**：注入 `streamOverride` / `catalogOverride` 时会跳过 TTS、自动记忆、主动聊天等副作用，避免测试里去碰平台通道和网络。

**图标树摇**：构建日志里的 "tree-shaken" 是正常的，Material 图标只留用到的。

---

## 8. 发布流程

### 推代码

仓库已配好 SSH：

```bash
cd app
git add -A
git commit -m "feat: xxx"
git push
```

SSH 私钥：`D:\AI\An\aichat\toolchain\ssh\id_ed25519_qi`（**不在仓库里**，别提交）
远端：`git@github.com:Ela351340/qi.git`

> 为什么用 SSH：这台机器访问 `github.com` 的网页被墙（DNS 污染），
> 但 22 端口通。SSH 绕开了网页授权页。

### 发版

```bash
git tag v1.5.2
git push origin v1.5.2
```

然后网页：Releases → Draft a new release → 选 tag → 上传 APK → Publish。

### 版本号约定

- `pubspec.yaml` 的 `version: 1.5.1+33`（name+build）
- 设置页「关于」里显示的版本号是**手写的字符串**，改版本时两处都要改：
  - `pubspec.yaml`
  - `settings_page.dart` 里 `_value('1.5.1 (构建 49)')`
  - 以及 `_openLicenses` 里的 `applicationVersion`

---

## 9. 已知限制（别当 bug 修）

| 现象 | 原因 |
|---|---|
| 主动聊天只在回前台时触发 | 安卓后台任务不可靠（尤其 ColorOS），刻意不做 WorkManager |
| 联网捉取可能失败 | DuckDuckGo HTML 页面对非浏览器流量有限制；失败会提示 |
| 抖音内容拿不到 | 没有公开 API；走第三方解析=数据出境，与定位冲突 |
| 表情库开箱是空的 | 版权原因，仓库不带第三方表情图 |
| TTS 音色选择有限 | 取决于手机装的 TTS 引擎 |
| 视频只显示卡片 | 视频理解需要公网可访问 URL，手机端做不了；后续可抽首帧 |
| `usesCleartextTraffic=true` | 为了连局域网 http 的 Ollama；只用 https 可以去掉 |

---

## 10. 待办（按优先级）

1. **豆包视觉外包**：图片 → 豆包视觉模型 → 描述 → 塞进上下文给主模型
   - 需要：独立的「视觉服务」配置（火山方舟 API Key）
   - 卡点：视频需要公网 URL，只能先做抽帧
2. **聊天中自动联网**（工具调用）：她判断需要查才搜，而不是只在人格页手动触发
   - 需要：`tools` 请求体 + tool_call 解析 + 循环
   - DeepSeek 和本地 qwen3 都支持
3. **首次启动引导**：配模型 → 设名字 → 开始聊（给朋友用更省事）
4. **GitHub Actions**：`flutter analyze` + `test` 自动跑
5. 搜索源可配置（Bing / 搜索 API）
6. 聊天列表虚拟化/分页（2000 条目前还能扛，再多要优化）

---

## 11. 安全与合规清单

**提交前必查**

- [ ] `git status` 里没有 `config.json`、`*.jks`、`*.keystore`、`local.properties`
- [ ] 代码里没有硬编码的 Key、内网 IP、个人路径
- [ ] 新增依赖是 MIT/BSD/Apache（不要 GPL/AGPL）
- [ ] 没有引入第三方版权素材（表情、字体、图标）

**仓库现状**（已核对）

- 单一提交，历史里没有内网 IP
- 无密钥文件
- 第三方声明：`THIRD_PARTY_NOTICES.md`（含 Twemoji CC-BY 4.0 署名）
- 图标：豆包生成，随 MIT 授权，声明里已写明

---

## 12. 常用排查

| 症状 | 先看 |
|---|---|
| 一填 Key 就报错 | Key 里是否有换行/中文；地址是否缺 `/v1` |
| 连接失败 | 设置 → 模型服务 → **测试连接**，看真实状态码 |
| 聊天卡顿 | 是否有大图背景；头像是否按 `cacheWidth` 解码 |
| 消息发出去没回复 | 模型名是否正确（DeepSeek 是 `deepseek-flash`） |
| 退出聊天后浮层残留 | `_dropOverlays()` 是否被调用（PopScope/deactivate/dispose） |
| 构建报 NDK/CMake 缺失 | 见第 4 节环境准备 |

---

## 13. 交接时需要拿到的东西

| 资产 | 位置 |
|---|---|
| 源码仓库 | GitHub `Ela351340/qi`（SSH 可推） |
| SSH 私钥 | `D:\AI\An\aichat\toolchain\ssh\id_ed25519_qi` |
| 发布用的 APK | `D:\AI\An\aichat\发布\` |
| 构建环境 | `D:\AI\An\aichat\toolchain\`（Flutter/JDK/SDK/Gradle 缓存） |
| 环境脚本 | `D:\AI\An\aichat\tools\flutter-env.ps1`（设置镜像与路径） |

**不要把私钥、API Key、`config.json` 交出去或提交到仓库。**
