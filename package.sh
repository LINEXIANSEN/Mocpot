#!/bin/bash

# Mocpot 打包脚本
# 用法: ./package.sh

set -e

APP_NAME="Mocpot"
BUILD_DIR="$HOME/Library/Developer/Xcode/DerivedData/PotPlayer-mac-eekpvrgkskpidgdjdimstwuazasc/Build/Products/Release"
OUTPUT_DIR="$HOME/Desktop"
DMG_NAME="${APP_NAME}-1.0.0"
DMG_PATH="$OUTPUT_DIR/$DMG_NAME.dmg"
TEMP_DMG="$OUTPUT_DIR/${DMG_NAME}_temp.dmg"

echo "🎬 开始打包 ${APP_NAME}..."

# 1. 构建 Release 版本
echo "📦 构建 Release 版本..."
xcodebuild -project PotPlayer-mac.xcodeproj \
           -scheme Mocpot \
           -configuration Release \
           clean build

# 2. 检查应用
APP_PATH="$BUILD_DIR/$APP_NAME.app"
if [ ! -d "$APP_PATH" ]; then
    echo "❌ 构建失败: 找不到 $APP_PATH"
    exit 1
fi

echo "✅ Release 版本构建成功"

# 3. 创建 DMG
echo "💿 创建 DMG 安装包..."

# 清理旧文件
rm -f "$DMG_PATH" "$TEMP_DMG"

# 创建临时 DMG
hdiutil create -volname "$APP_NAME" \
               -srcfolder "$APP_PATH" \
               -ov -format UDZO \
               "$TEMP_DMG"

# 重命名
mv "$TEMP_DMG" "$DMG_PATH"

echo ""
echo "✅ 打包完成！"
echo "📁 DMG 文件: $DMG_PATH"
echo ""
echo "📊 文件信息:"
ls -lh "$DMG_PATH"
echo ""
echo "🚀 发布方式:"
echo "   1. 直接分享 DMG 文件给用户"
echo "   2. 上传到 GitHub Releases"
echo "   3. 上传到 Mac App Store (需要开发者账号)"
echo ""
