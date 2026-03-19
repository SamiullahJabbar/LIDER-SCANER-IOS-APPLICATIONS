# Android Build Fix Guide

## ❌ Problem:
- Android v1 embedding deleted
- Android files missing
- Build failed

## ✅ Solution:

### Option 1: Recreate Android Folder (Recommended)

```bash
# Step 1: Backup your lib folder
cp -r lib lib_backup

# Step 2: Remove Android folder
rm -rf android

# Step 3: Recreate Android platform
flutter create --platforms=android .

# Step 4: Restore if needed
# (lib folder should be safe)

# Step 5: Get dependencies
flutter pub get

# Step 6: Generate icons
dart run flutter_launcher_icons

# Step 7: Build APK
flutter build apk --release
```

### Option 2: Quick Fix (If above doesn't work)

```bash
# Create new Flutter project with same name
cd ..
flutter create lidar_scanner_temp

# Copy Android folder
cp -r lidar_scanner_temp/android lidar_scanner_app/

# Go back to project
cd lidar_scanner_app

# Clean and rebuild
flutter clean
flutter pub get
dart run flutter_launcher_icons
flutter build apk --release
```

---

## 📝 After Fix:

### Update App Name:

**1. Create `android/app/src/main/res/values/strings.xml`:**
```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">LiDAR Scanner</string>
</resources>
```

**2. Update `android/app/src/main/AndroidManifest.xml`:**
```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application
        android:label="@string/app_name"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">
        
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">
            
            <meta-data
              android:name="io.flutter.embedding.android.NormalTheme"
              android:resource="@style/NormalTheme"
              />
            
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>
        
        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />
    </application>
    
    <!-- Permissions -->
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.CAMERA"/>
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
</manifest>
```

**3. Update `android/app/build.gradle`:**
```gradle
android {
    namespace "com.lidarscanner.app"
    compileSdkVersion 34
    
    defaultConfig {
        applicationId "com.lidarscanner.app"
        minSdkVersion 24
        targetSdkVersion 34
        versionCode 1
        versionName "1.0.0"
    }
    
    buildTypes {
        release {
            signingConfig signingConfigs.debug
        }
    }
}
```

---

## 🚀 Complete Commands:

```bash
# Fix Android
flutter create --platforms=android .

# Get dependencies
flutter pub get

# Generate icons
dart run flutter_launcher_icons

# Clean build
flutter clean

# Build APK
flutter build apk --release
```

---

## ✅ Expected Result:

- Android folder recreated
- v2 embedding enabled
- Icons generated
- App name: "LiDAR Scanner"
- APK builds successfully

---

## 📱 APK Location:

```
build/app/outputs/flutter-apk/app-release.apk
```

---

## ⚠️ Important:

Your `lib` folder is safe! Only Android platform files will be recreated.

Run the commands and build will work! 🚀
