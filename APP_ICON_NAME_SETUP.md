# App Icon & Name Setup Guide

## ✅ Changes Made

### 1. pubspec.yaml Updated:
- Added `flutter_launcher_icons` package
- Configured icon path: `assets/icons/icon.png`
- Set adaptive icon background: `#0A2463` (Deep Ocean Blue)
- App description updated: "LiDAR Pro Scanner - Professional 3D Scanning App"

## 🚀 Commands to Run

### Step 1: Install Dependencies
```bash
flutter pub get
```

### Step 2: Generate App Icons
```bash
# Generate icons for Android & iOS
flutter pub run flutter_launcher_icons
```

### Step 3: Update App Name

#### Android:
Create/Update `android/app/src/main/res/values/strings.xml`:
```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">LiDAR Scanner</string>
</resources>
```

Then update `android/app/src/main/AndroidManifest.xml`:
```xml
<application
    android:label="@string/app_name"
    android:icon="@mipmap/ic_launcher">
```

#### iOS:
Update `ios/Runner/Info.plist`:
```xml
<key>CFBundleName</key>
<string>LiDAR Scanner</string>
<key>CFBundleDisplayName</key>
<string>LiDAR Scanner</string>
```

### Step 4: Build APK
```bash
flutter build apk --release
```

---

## 📱 Result

After running these commands:
- ✅ App icon will be your custom icon from `assets/icons/icon.png`
- ✅ App name will be "LiDAR Scanner"
- ✅ Adaptive icon with blue background (#0A2463)

---

## 🎨 Icon Requirements

Your icon (`assets/icons/icon.png`) should be:
- Size: 1024x1024 pixels (minimum 512x512)
- Format: PNG with transparency
- Design: Clear, recognizable at small sizes

---

## 📝 Quick Setup (All Commands)

```bash
# 1. Get dependencies
flutter pub get

# 2. Generate icons
flutter pub run flutter_launcher_icons

# 3. Build APK
flutter build apk --release

# APK location:
# build/app/outputs/flutter-apk/app-release.apk
```

---

## ✨ Summary

**Icon:** `assets/icons/icon.png` ✅
**Name:** "LiDAR Scanner" ✅
**Package:** `flutter_launcher_icons` added ✅

Run the commands above to apply changes! 🚀
