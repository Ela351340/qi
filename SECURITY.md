# 安全说明

## 会存储什么

| 数据 | 位置 | 是否加密 |
|---|---|---|
| 聊天记录 | 应用私有目录（SharedPreferences） | 否，受应用沙箱保护 |
| 记忆文件 | `<应用文档目录>/memory/*.md` | 否，明文 markdown |
| 附件副本 | `<应用文档目录>/attachments/` | 否 |
| **API Key** | **Android Keystore 加密存储** | **是** |
| 头像 / 背景 | SharedPreferences（base64） | 否 |

系统备份已关闭（`android:allowBackup="false"`），所以 Key 不会进云备份。

## 会联网吗

只在两种情况下联网，且目标都是**你自己配置的地址**：

1. 聊天时调用模型接口
2. 人格页点「联网补全人格」时，向 `html.duckduckgo.com` 搜索并抓取结果页

没有埋点、没有崩溃上报、没有第三方 SDK。

## 报告问题

如果你发现安全问题（比如 Key 被写入日志、数据被发到意料之外的地址），
请**不要**开公开 issue，直接通过仓库主页的联系方式私信，我会尽快修。

## 已知取舍

- `usesCleartextTraffic=true`：为了让 App 能连局域网 http 的 Ollama。
  副作用是允许明文 HTTP；如果你只用 https 服务，可以去掉这一项。
- 局域网直连 Ollama 会把电脑端口暴露给同一网络。更安全的做法是用
  `adb reverse tcp:11434 tcp:11434`（仅 USB 生效）。
