# 第三方组件与素材声明 / Third-Party Notices

本文件列出本项目使用的第三方组件与素材，以及它们的许可条款。
分发本应用（含源码与二进制）时请保留本文件。

---

## 一、运行时代码依赖

全部为 OSI 认可、**允许商业使用**的宽松许可。

| 包 | 许可 | 用途 |
|---|---|---|
| flutter / flutter_local_notifications / image_picker / path_provider / shared_preferences / http 等（共 73 个） | BSD-3-Clause | Flutter 与官方插件生态 |
| jni、jni_flutter、jni_util 等（共 6 个） | Apache-2.0 | 图片选择插件的原生桥接 |
| flutter_animate、crypto、xml 等（共 4 个） | MIT | 动画、加密、XML 解析 |
| cupertino_icons 等（共 1 个） | BSD-2-Clause | 图标 |
| dbus（1 个） | MPL-2.0 | 仅 Linux 桌面通知路径使用，Android 构建不参与；MPL 为文件级弱著佐权，**不影响商业分发** |

> BSD-3 与 Apache-2.0 的署名义务已通过应用内「设置 → 关于 → 开源许可」页
> （Flutter `showLicensePage`）随包分发，聚合展示每个依赖的完整许可证文本。

## 二、图形素材

### Twemoji（表情图形）

- 文件位置：`assets/emoji/*.png`（85 个 72×72 PNG）
- 来源：<https://github.com/jdecked/twemoji>（原 Twitter Twemoji）
- 许可：**CC-BY 4.0** —— 允许商业使用，**必须署名**
- 署名文字：*Emoji graphics by Twemoji (Twitter, Inc. and other contributors), licensed under CC-BY 4.0.*
- 修改说明：仅从原始 SVG 导出的 72px PNG 中挑选了本项目用到的子集，未改动图形本身

### Material Icons

- 随 Flutter 分发，Apache-2.0；构建时已 tree-shaking

### Android 启动图标

- 位置：`android/app/src/main/res/mipmap-*/ic_launcher*.png`、`mipmap-anydpi-v26/ic_launcher.xml`
- 来源：项目作者使用 **豆包（Doubao）** 生成的角色插画，作者对其使用不设限制
- 授权：**随本项目的 MIT 许可一并提供，任何人可以自由使用、修改、再分发**
- 说明：这是 AI 生成图像。不同司法辖区对 AI 生成物的版权认定不同，
  本项目**不主张**对该图像的独占权利，也不对它提供任何担保（见 LICENSE 免责条款）

### `assets/stickers/`（内置表情）

- 开源版本**不包含任何第三方表情图**，只保留空的 `pack.json` 与格式说明
- 用户可以放入自己的表情，风险自负；贡献表情图时请确保有分发权

## 三、已移除的内容（历史说明）

### 曾经内置的 42 张表情图

开发阶段曾内置一批来源不明的表情（与开发机上的测试素材哈希一致），
**在公开前已全部删除**。现在仓库中不存在任何未授权的第三方图片。

## 四、不随包分发的内容

- 人格档案文本（`云若·*.md`）：仅开发期参考资料，未打包进 APK
- 测试用字体（simhei.ttf、seguiemj.ttf）：仅在开发机的测试中从系统目录加载，**未入库、未打包**
- 所有用户数据（对话、记忆、API Key）：仅存于用户设备本地
