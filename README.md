# LiDAR Scanner App - Phase 1

Professional iPhone LiDAR scanning application built with Flutter.

## Features

### Core Features
- Real-time LiDAR capture using ARKit
- Motion tracking + depth fusion
- Raw scan packaging for server upload
- Offline scan storage
- Secure upload system
- Scan quality indicator
- Metadata tagging

### Value Features
- Real-time scan progress visualization
- Scan quality meter (coverage & stability)
- Offline capture with delayed upload
- Auto segmentation of walls/floors/objects
- Scan session history on device
- Secure encrypted data transfer
- On-device interactive 3D preview
- Automatic retry upload if network drops

## Requirements

- iOS 14.0 or higher
- iPhone with LiDAR sensor (iPhone 12 Pro or newer)
- Flutter 3.24.3 or higher
- Xcode 14 or higher

## Setup

1. Install dependencies:
```bash
flutter pub get
```

2. Configure backend URL in `lib/utils/constants.dart`:
```dart
static const String baseUrl = 'http://your-django-backend.com/api';
```

3. Run the app:
```bash
flutter run
```

## Project Structure

```
lib/
├── models/          # Data models
├── services/        # API, storage, ARKit services
├── screens/         # UI screens
├── widgets/         # Reusable widgets
├── providers/       # State management
└── utils/           # Constants and helpers
```

## Tech Stack

- Flutter 3.24.3
- ARKit Plugin for LiDAR
- Dio for HTTP requests
- SQLite for local storage
- Provider for state management
- Model Viewer Plus for 3D preview

## Next Steps

1. Implement ARKit scanning service
2. Create scanning UI
3. Implement local storage
4. Add upload functionality
5. Build 3D preview
6. Add scan history

## License

Private - All rights reserved
# LIDER-SCANER-IOS-APPLICATIONS
