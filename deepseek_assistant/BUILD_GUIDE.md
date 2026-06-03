# AI 助手 Android APK 构建指南

## 📋 前置准备

### 1. 打开项目

1. 打开 **Android Studio**
2. 点击 **File → Open**
3. 浏览并选择项目路径：`d:\个人项目ai版\deepseek_assistant`
4. 点击 **OK**

### 2. 等待 Gradle 同步

- Android Studio 会自动检测并同步 Gradle 配置
- 首次同步会下载依赖，大约需要 **5-15 分钟**（取决于网络）
- 底部进度条会显示同步状态

**同步完成标志**：
- 底部状态栏显示 "Gradle sync finished"
- 没有红色错误提示

## 🔧 配置 Android SDK

### 检查 NDK 是否已安装

1. **Tools → SDK Manager**
2. 点击 **SDK Tools** 标签
3. 查找 **NDK** 选项
4. 如果没有安装：
   - ✅ 勾选 **NDK (Side by side)**
   - 点击 **Apply** 或 **OK**
   - 等待下载安装完成（约 1-2GB）

## 🚀 构建 APK

### 方法一：使用菜单构建

1. **点击顶部菜单**：Build → Build Bundle(s) / APK(s) → Build APK
2. **等待构建**：
   - 底部会显示构建进度
   - Debug 版本约需 3-5 分钟
   - Release 版本约需 5-10 分钟
3. **构建完成**：
   - Android Studio 右下角会弹出通知
   - 点击 **"locate"** 可以直接打开 APK 文件夹

### 方法二：使用快捷键

1. **编译项目**：`Ctrl + F9`（或点击 🔨 按钮）
2. **构建 APK**：`Ctrl + Shift + F12`
3. 或直接运行到设备：`Shift + F10`

### 方法三：使用 Terminal

1. 点击 Android Studio 底部的 **Terminal** 标签
2. 输入命令：

```bash
# 构建 Debug 版本（推荐）
flutter build apk --debug

# 或构建 Release 版本
flutter build apk --release
```

## 📂 APK 文件位置

构建成功后，APK 文件会在：

```
d:\个人项目ai版\deepseek_assistant\build\app\outputs\flutter-apk\
├── app-debug.apk          # 调试版本（约 30-50MB）
└── app-release.apk        # 发布版本（约 20-40MB）
```

## 📱 安装到手机

### 方法一：直接复制安装

1. 将 APK 文件复制到手机存储
2. 在手机上点击该 APK 文件
3. 如果提示"禁止安装未知来源应用"：
   - 设置 → 安全 → 允许未知来源
   - 或者在安装时勾选"允许"
4. 点击安装 → 完成

### 方法二：使用数据线（推荐）

1. **连接手机**：用 USB 数据线连接手机和电脑
2. **启用调试模式**：
   - 手机设置 → 关于手机
   - 连续点击"版本号" 7 次
   - 返回设置 → 开发者选项 → 启用 USB 调试
3. **允许调试**：
   - 手机上会弹出"允许 USB 调试"对话框
   - 点击"允许"
4. **在 Android Studio 中运行**：
   - 点击绿色运行按钮 ▶️
   - 或使用快捷键：`Shift + F10`
5. **选择设备**：
   - 选择已连接的手机设备
   - 点击 OK
6. **等待安装**：
   - 应用会自动安装并启动

## ⚙️ Release 版本配置（可选）

Release 版本需要签名配置。

### 1. 生成签名密钥

打开 **Terminal**，输入：

```bash
keytool -genkey -v -keystore deepseek-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias deepseek
```

按提示输入密钥库密码和保护密码。

### 2. 配置签名信息

在 `android/app/build.gradle.kts` 中添加：

```kotlin
signingConfigs {
    create("release") {
        storeFile = file("deepseek-release.jks")
        storePassword = "你的密钥库密码"
        keyAlias = "deepseek"
        keyPassword = "你的密钥密码"
    }
}

buildTypes {
    getByName("release") {
        signingConfig = signingConfigs.getByName("release")
    }
}
```

### 3. 构建 Release 版本

```bash
flutter build apk --release
```

## 🔍 常见问题

### Q1: Gradle 同步失败

**解决方法**：
1. 点击 **File → Invalidate Caches → Invalidate and Restart**
2. 或者手动删除 `.gradle` 和 `build` 文件夹后重新同步

### Q2: NDK 安装失败

**解决方法**：
1. 打开 Android Studio
2. **Tools → SDK Manager → SDK Tools**
3. 取消勾选 **NDK**
4. 点击 Apply
5. 重新勾选 **NDK**
6. 再次点击 Apply

### Q3: 网络超时

**解决方法**：
1. 检查网络连接
2. 配置 Gradle 镜像（已在项目中配置）
3. 重试构建

### Q4: 手机无法识别

**解决方法**：
1. 检查 USB 驱动是否安装
2. 尝试更换 USB 接口
3. 重新插拔数据线
4. 在手机上重新允许 USB 调试

## ✨ 优化建议

### 减小 APK 体积

在 `android/app/build.gradle.kts` 中添加：

```kotlin
buildTypes {
    getByName("release") {
        isMinifyEnabled = true
        isShrinkResources = true
        proguardFiles(
            getDefaultProguardFile("proguard-android-optimize.txt"),
            "proguard-rules.pro"
        )
    }
}
```

### 开启 R8 代码混淆

Release 版本会自动启用代码混淆和压缩。

## 📞 技术支持

如果遇到其他问题，可以：
1. 查看 Android Studio 的 Event Log（View → Tool Windows → Event Log）
2. 搜索 Flutter 官方文档
3. 查看项目 Issues

---

**祝构建成功！🎉**
