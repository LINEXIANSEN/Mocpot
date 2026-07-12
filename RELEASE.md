# Mocpot 发布指南

## 当前状态

✅ 应用已构建 (Release)  
✅ DMG 安装包已创建  
⚠️ 应用使用 Ad-hoc 签名（未公证）

## 文件位置

| 文件 | 路径 |
|------|------|
| DMG 安装包 | `~/Desktop/Mocpot-1.0.0.dmg` (2.0MB) |
| App 应用 | `~/Desktop/Mocpot.app` |
| 项目源码 | `~/Desktop/PotPlayer-mac/` |

---

## 发布方式

### 方式 1: 直接分享 (最简单)

直接将 `Mocpot.app` 或 `Mocpot-1.0.0.dmg` 发给用户。

用户首次打开时需要：
1. 右键点击应用 → 选择"打开"
2. 或在 系统设置 → 隐私与安全性 中允许打开

### 方式 2: GitHub Releases (推荐)

```bash
# 1. 创建 GitHub 仓库
# 2. 推送代码
cd ~/Desktop/PotPlayer-mac
git init
git add .
git commit -m "Release v1.0.0"
git remote add origin https://github.com/yourusername/Mocpot.git
git push -u origin main

# 3. 创建 Release
gh release create v1.0.0 ~/Desktop/Mocpot-1.0.0.dmg \
  --title "Mocpot v1.0.0" \
  --notes "macOS 全功能视频播放器"
```

### 方式 3: Mac App Store

需要 Apple Developer 账号 ($99/年)：

1. 在 Xcode 中配置 Signing & Capabilities
2. Archive → Upload to App Store Connect
3. 提交审核

### 方式 4: 公证 (推荐商业发布)

```bash
# 1. 签名
codesign --sign "Developer ID Application: YOUR NAME" Mocpot.app

# 2. 公证
xcrun notarytool submit Mocpot-1.0.0.dmg \
  --apple-id your@email.com \
  --team-id YOUR_TEAM_ID \
  --password app-specific-password

# 3. 装订
xcrun stapler staple Mocpot-1.0.0.dmg
```

---

## 版本更新

更新版本号：
1. 打开 Xcode 项目
2. 选择 Target → Mocpot
3. 修改 `MARKETING_VERSION` (如 1.1.0)
4. 重新运行 `package.sh`

---

## 自动更新

如需自动更新功能，可集成:
- Sparkle Framework: https://sparkle-project.org

```swift
// 在 AppDelegate 中添加
import Sparkle

func applicationDidFinishLaunching(_ notification: Notification) {
    let updater = SUUpdater.shared()
    updater?.feedURL = URL(string: "https://yourdomain.com/appcast.xml")
}
```

---

## 故障排除

### 用户无法打开应用
```bash
# 用户运行此命令移除隔离属性
xattr -cr /Applications/Mocpot.app
```

### 签名问题
```bash
# 检查签名
codesign -dv --verbose=4 Mocpot.app

# 验证
spctl -a -v Mocpot.app
```
