# 栖 · Qi

一个安卓端的 AI 陪伴聊天应用。她自己挑表情、记得你说过的小事、会主动找你说话——
**所有数据都留在你自己的设备上，模型也可以跑在你自己的机器上。**

> 名字取自「栖」：停在你这里，不走。

---

## 功能

**聊天**
- QQ 风格的单聊界面，气泡、时间分隔、撤回、删除
- 流式输出（逐字上屏），思考内容自动隐藏
- 图片 / 视频 / 文件发送，图片可全屏查看
- 消息长按菜单：复制 / 撤回 / 删除

**她**
- 人格档案：一句话、性格标签、开场白、人设正文，全部可改
- **联网补全人格**：给一个名字，她自己搜资料、整理成人设
- **外置记忆**：以 markdown 文件存在应用目录，可以直接编辑
  （`facts.md` / `episodes.md` / `profile.md`，一行一条）
- **自动整理记忆**：聊够轮数自动提炼，去重后入库
- **主动开口**：久没联系时她先说一句（默认 0–10 点不打扰）
- **表情**：她自己会按心情挑表情发；你也可以导入自己的表情包

**外观**
- 浅色 / 深色主题（深色为纯黑）
- 8 套预设配色（亚麻、微信绿、iMessage、Telegram、WhatsApp、深海、夜绿、纯黑蓝）
- 23 种气泡颜色，背景可换纯色或图片
- 头像裁剪：支持完整模式（不裁边、留白透明）

**模型**
- 任意 OpenAI 兼容接口（DeepSeek、通义、Ollama、自建中转）
- 一键预设 + 连接测试（显示真实状态码）
- **API Key 存进系统密钥库**（Android Keystore），不落明文

---

## 快速开始

### 环境

- Flutter 3.47+（Dart 3.13+）
- Android SDK 36，JDK 17
- 因为用到 `jni`，首次构建需要：
  ```bash
  sdkmanager "ndk;28.2.13676358" "cmake;3.22.1" "platforms;android-34"
  ```

### 构建

```bash
cd app
flutter pub get
flutter build apk --release
```

产物：`build/app/outputs/flutter-apk/app-release.apk`

> 国内网络可在 `~/.gradle/init.gradle.kts` 里加阿里云镜像，
> 并把 `gradle-wrapper.properties` 的下载地址换成腾讯镜像。

### 配置模型

装好后进 **设置 → 模型服务 → 添加模型服务**：

| 服务 | 接口地址 | 模型名 |
|---|---|---|
| DeepSeek | `https://api.deepseek.com/v1` | `deepseek-flash` |
| 通义千问 | `https://dashscope.aliyuncs.com/compatible-mode/v1` | `qwen-plus` |
| 本地 Ollama | `http://<电脑IP>:11434/v1` | `qwen3:8b` |

点「测试连接」确认返回 200 即可。

---

## 表情包

**仓库不自带任何第三方表情图**（版权原因）。自带的表情目录是空的，
但机制完整：

```
assets/stickers/ai/pack.json     # 她会发的表情
assets/stickers/user/pack.json   # 你自己挑的表情
```

`pack.json` 格式：

```json
{
  "packName": "我的表情",
  "stickers": [
    { "id": "01", "file": "01.png", "label": "开心", "tags": ["高兴", "笑"] }
  ]
}
```

`label` 是主标签，`tags` 是别名，模型输出 `[s:开心]` 时就会发这张。

也可以直接在 App 里导入：表情面板 → 「我的」→ ＋ 选图。

---

## 隐私

- 聊天记录、记忆、设置全部存在本机应用目录
- **API Key 存在 Android Keystore 加密存储**，不写明文、不进系统备份（`allowBackup=false`）
- 唯一的联网行为：调用你自己填的模型接口
- 没有账号体系、没有埋点、没有第三方 SDK

---

## 许可证

源码以 **MIT** 发布，见 [LICENSE](LICENSE)。

第三方组件与素材的许可声明见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)，
包括 Twemoji（CC-BY 4.0）的署名要求。

---

## 交接

接手的同学请先读 [HANDOVER.md](HANDOVER.md)：代码地图、构建环境、设计决策、发布流程、已知限制都在里面。

## 贡献

见 [CONTRIBUTING.md](CONTRIBUTING.md)。欢迎提 issue，尤其是：

- 不同模型服务的兼容问题
- 安卓各家 ROM 的通知/后台差异
- 新的配色方案
