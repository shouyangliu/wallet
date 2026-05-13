#!/bin/bash
set -e

cd "$(dirname "$0")"

echo "=== 清理旧构建 ==="
flutter clean

echo "=== 获取依赖 ==="
flutter pub get

echo "=== 编译 release APK ==="
flutter build apk --release

echo ""
echo "=== 编译完成 ==="
echo "APK 位置:"
ls -lh build/app/outputs/flutter-apk/app-release.apk 2>/dev/null || \
ls -lh build/app/outputs/flutter-apk/*.apk 2>/dev/null
