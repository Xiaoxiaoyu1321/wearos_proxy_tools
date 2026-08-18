# WearOS Proxy Tools

一个用于 Wear OS 的 Flutter 代理设置工具，通过 [Shizuku](https://shizuku.rikka.app/) 读取和修改 Android 全局代理（`Settings.Global.http_proxy`）。

## 功能特性

- 查看当前系统全局代理地址
- 设置自定义全局代理（格式：`IP:端口`，例如 `192.168.1.100:8080`）
- 一键清除已设置的全局代理
- 通过 Shizuku 调用系统 `settings` 命令，无需 root 即可修改系统级代理
- 适配 Wear OS 手表屏幕

## 环境要求

- Wear OS 设备（Android 11 及以上推荐）
- 已安装并激活 [Shizuku](https://shizuku.rikka.app/)
- 已授予本应用 Shizuku 权限

## 使用说明

1. 在手表上安装并启动 Shizuku，通过 adb 或 root 方式激活。
2. 安装本应用的 APK。
3. 打开应用，首次使用时允许 Shizuku 权限。
4. 在输入框中填写代理地址，例如：
   ```
   192.168.1.100:8080
   ```
5. 点击 **设置代理** 写入全局代理。
6. 点击 **清除代理** 恢复系统默认无代理状态。
7. 顶部“当前代理”文本框会显示系统当前已设置的代理地址。

## 预览包

仓库中的预览包位于：

```
dist/wearos_proxy_tools-preview.zip
```

ZIP 内包含：

- `wearos_proxy_tools-preview.apk`：Debug 预览 APK
- `README.txt`：简要安装说明

## 本地构建

```bash
flutter pub get
flutter build apk --debug
```

生成的 APK 位于：

```
build/app/outputs/flutter-apk/app-debug.apk
```

## 项目结构

```text
lib/main.dart                                      # Flutter UI + MethodChannel
android/app/src/main/kotlin/.../MainActivity.kt    # Shizuku 原生调用
android/app/src/main/AndroidManifest.xml           # ShizukuProvider + Wear OS 声明
android/app/build.gradle.kts                       # Shizuku API/Provider 依赖
```

## 技术栈

- Flutter 3.47.0 / Dart 3.13.0
- Shizuku API 13.1.5
- Kotlin
- Android Gradle Plugin
