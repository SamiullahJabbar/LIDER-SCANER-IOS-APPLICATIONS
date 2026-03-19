# Camera & LiDAR Setup Guide

## Current Status: Development Mode

The app is currently running in **simulation mode** for development and testing purposes.

## Why Camera Doesn't Open?

1. **Web Platform**: Real camera access requires native iOS platform
2. **ARKit Required**: LiDAR scanning only works on iOS devices
3. **Simulation**: Current implementation shows simulated camera preview

## To Enable Real Camera:

### Requirements:
- iPhone 12 Pro or newer (with LiDAR sensor)
- iOS 14.0 or higher
- Xcode installed on Mac
- Physical iOS device connected

### Steps:

1. **Connect iOS Device**
   ```bash
   # Check connected devices
   flutter devices
   ```

2. **Run on iOS Device**
   ```bash
   # Run on connected iPhone
   flutter run -d <device-id>
   ```

3. **Camera Permissions**
   - Already configured in `ios/Runner/Info.plist`
   - App will request camera permission on first launch

## Real Implementation (iOS Native)

For production, you need to implement:

### 1. ARKit Camera Integration
```swift
// In iOS native code (Swift)
import ARKit

let arView = ARView()
let configuration = ARWorldTrackingConfiguration()
configuration.sceneReconstruction = .meshWithClassification
arView.session.run(configuration)
```

### 2. LiDAR Data Capture
```swift
// Capture depth data
func session(_ session: ARSession, didUpdate frame: ARFrame) {
    guard let depthData = frame.sceneDepth else { return }
    // Process depth data
}
```

### 3. Point Cloud Processing
```swift
// Extract point cloud
let pointCloud = frame.rawFeaturePoints
let points = pointCloud?.points
```

## Current Simulation Features:

✅ UI/UX Flow (Complete)
✅ Database Integration (Working)
✅ Navigation (Working)
✅ Quality Analysis (Simulated)
✅ Coverage Calculation (Simulated)

❌ Real Camera Feed (Requires iOS device)
❌ Actual LiDAR Data (Requires iOS device)
❌ Real-time Depth Sensing (Requires iOS device)

## Testing on iOS Device:

1. Open project in Xcode:
   ```bash
   open ios/Runner.xcworkspace
   ```

2. Select your iPhone as target device

3. Click Run (⌘R)

4. Grant camera permissions when prompted

5. Real camera will open with LiDAR scanning

## Alternative: Use iOS Simulator

Note: iOS Simulator doesn't support camera or LiDAR, but you can test UI flow.

```bash
flutter run -d "iPhone 14 Pro"
```

## Production Deployment:

For App Store release:
1. Implement native ARKit integration
2. Add proper error handling for non-LiDAR devices
3. Test on multiple iPhone models
4. Add fallback for older iPhones (without LiDAR)

## Need Help?

- ARKit Documentation: https://developer.apple.com/arkit/
- Flutter ARKit Plugin: https://pub.dev/packages/arkit_plugin
- LiDAR Guide: https://developer.apple.com/documentation/arkit/arworldtrackingconfiguration/scenereconstructionoption

---

**Current Mode**: Development/Simulation
**For Real Camera**: Deploy to iOS device with LiDAR
