import 'dart:io';
import 'package:flutter/foundation.dart';

class PlatformService {
  static PlatformService? _instance;
  static PlatformService get instance {
    _instance ??= PlatformService._();
    return _instance!;
  }

  PlatformService._();

  // Check if running on iOS
  bool get isIOS {
    if (kIsWeb) return false;
    return Platform.isIOS;
  }

  // Check if running on Android
  bool get isAndroid {
    if (kIsWeb) return false;
    return Platform.isAndroid;
  }

  // Check if running on Web
  bool get isWeb => kIsWeb;

  // Check if LiDAR is available (iOS only)
  bool get hasLiDAR {
    // LiDAR is only available on iOS devices
    // iPhone 12 Pro, 12 Pro Max, 13 Pro, 13 Pro Max, 14 Pro, 14 Pro Max, 15 Pro, 15 Pro Max
    return isIOS;
  }

  // Get scanning method based on platform
  String get scanningMethod {
    if (isIOS) {
      return 'LiDAR + ARKit';
    } else if (isAndroid) {
      return 'ARCore + Depth API';
    } else {
      return 'Simulation';
    }
  }

  // Get platform name
  String get platformName {
    if (isIOS) return 'iOS';
    if (isAndroid) return 'Android';
    if (isWeb) return 'Web';
    return 'Unknown';
  }

  // Check if device supports 3D scanning
  bool get supports3DScanning {
    return isIOS || isAndroid;
  }

  // Get accuracy level
  String get accuracyLevel {
    if (isIOS) {
      return 'High (LiDAR)';
    } else if (isAndroid) {
      return 'Medium (ARCore)';
    } else {
      return 'Simulation';
    }
  }

  // Get recommended distance
  String get recommendedDistance {
    if (isIOS) {
      return '1-3 meters';
    } else if (isAndroid) {
      return '1-2 meters';
    } else {
      return 'N/A';
    }
  }

  // Check if real camera is available
  bool get hasRealCamera {
    return !isWeb;
  }
}
