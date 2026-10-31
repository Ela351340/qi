# 贡献指南

## 提交前

```bash
cd app
flutter analyze     # 必须 0 issue
flutter test        # 必须全绿
```

如果改了界面，golden 会失败，用 `flutter test --update-goldens` 重新生成，
并**看一眼生成的图**再提交。

## 代码约定

- 颜色一律从 `AppColors`（主题扩展）取，不要写死色值
- 尺寸常量放 `AppMetrics`，不要散落魔法数字
- 新增用户可见的文案用中文，注释也用中文
- 不引入 GPL/AGPL 依赖；新增依赖前先确认许可

## 提 PR 时说明

- 改了什么、为什么
- 有没有改 golden
- 在什么设备 / 系统版本上验证过

## 不要提交

- `android/local.properties`、`*.jks`、`*.keystore`
- `config.json`（本地密钥配置）
- 任何第三方表情图（版权风险）
- `build/`、`.dart_tool/`

`.gitignore` 已经覆盖，但提交前请再看一眼 `git status`。
