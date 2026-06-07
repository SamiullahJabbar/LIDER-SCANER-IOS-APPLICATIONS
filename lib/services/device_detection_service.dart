import 'package:flutter/foundation.dart';
// Production-ready Device Detection Service
// Detects iPhone LiDAR, Android ARCore, or falls back to camera
// NO mocks, NO simulations - real device capability detection
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:device_info_plus/device_info_plus.dart';

enum DeviceCapability {
  lidarIOS('LIDAR_IOS'),
  arkitIOS('ARKIT_IOS'),
  arcoreAndroid('ARCORE_ANDROID'),
  cameraFallback('CAMERA_BASED');

  final String backendValue;
  const DeviceCapability(this.backendValue);
}

class DeviceDetectionService {
  static const MethodChannel _channel = MethodChannel('com.lidarscanner/native');
  static DeviceDetectionService? _instance;
  
  DeviceCapability? _cachedCapability;
  String? _arCapabilityLevel;
  
  static DeviceDetectionService get instance {
    _instance ??= DeviceDetectionService._();
    return _instance!;
  }
  
  DeviceDetectionService._();
  
  /// Detect device capability with caching
  Future<DeviceCapability> detectDeviceCapability() async {
    if (_cachedCapability != null) {
      return _cachedCapability!;
    }
    
    try {
      if (Platform.isIOS) {
        final hasLiDAR = await _checkiOSLiDAR();
        final hasARKit = await _checkiOSARKit();
        
        if (hasLiDAR) {
          _cachedCapability = DeviceCapability.lidarIOS;
          _arCapabilityLevel = 'LiDAR + ARKit';
          return DeviceCapability.lidarIOS;
        } else if (hasARKit) {
          _cachedCapability = DeviceCapability.arkitIOS;
          _arCapabilityLevel = 'ARKit Only';
          return DeviceCapability.arkitIOS;
        }
      } else if (Platform.isAndroid) {
        final hasARCore = await _checkAndroidARCore();
        if (hasARCore) {
          _cachedCapability = DeviceCapability.arcoreAndroid;
          _arCapabilityLevel = 'ARCore';
          return DeviceCapability.arcoreAndroid;
        }
      }
    } catch (e) {
      debugPrint('⚠️ Device detection error: $e');
    }
    
    // Fallback to camera
    _cachedCapability = DeviceCapability.cameraFallback;
    _arCapabilityLevel = 'Camera Fallback';
    return DeviceCapability.cameraFallback;
  }
  
  /// Check if iOS device has LiDAR sensor
  Future<bool> _checkiOSLiDAR() async {
    try {
      // Try native method first (most accurate)
      final bool hasLiDAR = await _channel.invokeMethod('isLiDARAvailable');
      return hasLiDAR;
    } catch (e) {
      // Fallback: Check device model
      return await _checkiOSDeviceModelForLiDAR();
    }
  }

  /// Check if iOS device supports ARKit
  Future<bool> _checkiOSARKit() async {
    try {
      // ARKit requires iOS 11+ and A9+ processor
      // All iPhone 7 and newer support ARKit
      final deviceModel = await getDeviceModel();
      final modelLower = deviceModel.toLowerCase();
      
      // Check if it's a supported iPhone model
      if (modelLower.contains('iphone')) {
        // iPhone 7 and newer support ARKit
        if (modelLower.contains('iphone 7') ||
            modelLower.contains('iphone 8') ||
            modelLower.contains('iphone x') ||
            modelLower.contains('iphone xs') ||
            modelLower.contains('iphone xr') ||
            modelLower.contains('iphone 1') || // 10, 11, 12, 13, 14, 15
            modelLower.contains('iphone 14') ||
            modelLower.contains('iphone 15')) {
          return true;
        }
      }
      
      // iPad Pro and newer iPads support ARKit
      if (modelLower.contains('ipad')) {
        return true;
      }
      
      return false;
    } catch (e) {
      debugPrint('⚠️ ARKit check error: $e');
      return false;
    }
  }

  /// Check iOS device model for LiDAR (fallback method)
  Future<bool> _checkiOSDeviceModelForLiDAR() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      final iosInfo = await deviceInfo.iosInfo;
      final model = iosInfo.model.toLowerCase();
      final name = iosInfo.name.toLowerCase();
      
      // LiDAR available on:
      // - iPhone 12 Pro/Pro Max and newer Pro models
      // - iPad Pro 2020+
      
      if (model.contains('iphone')) {
        // Check for Pro models (LiDAR)
        if (name.contains('pro') && !name.contains('max')) {
          if (name.contains('12') || name.contains('13') || 
              name.contains('14') || name.contains('15') ||
              name.contains('16') || name.contains('17')) {
            return true;
          }
        }
        // iPhone 12/13/14/15/16/17 Pro Max also have LiDAR
        if (name.contains('pro max')) {
          if (name.contains('12') || name.contains('13') || 
              name.contains('14') || name.contains('15') ||
              name.contains('16') || name.contains('17')) {
            return true;
          }
        }
        return false;
      } else if (model.contains('ipad') && model.contains('pro')) {
        // iPad Pro 2020+ has LiDAR
        return true;
      }
      
      return false;
    } catch (e) {
      debugPrint('⚠️ iOS device info error: $e');
      return false;
    }
  }
  
  /// Check if Android device supports ARCore
  Future<bool> _checkAndroidARCore() async {
    try {
      // Try native method
      final bool hasARCore = await _channel.invokeMethod('isARCoreSupported');
      return hasARCore;
    } catch (e) {
      // Fallback: Check if ARCore services are available
      try {
        final deviceInfo = DeviceInfoPlugin();
        final androidInfo = await deviceInfo.androidInfo;
        
        // ARCore requires Android 7.0+ and specific hardware
        if (androidInfo.version.sdkInt >= 24) {
          // Most modern Android devices support ARCore
          // This is a basic check - native method is more accurate
          return true;
        }
        
        return false;
      } catch (e) {
        debugPrint('⚠️ Android device info error: $e');
        return false;
      }
    }
  }
  
  /// Get device capability as string for backend
  Future<String> getDeviceTypeForBackend() async {
    final capability = await detectDeviceCapability();
    return capability.backendValue;
  }
  
  /// Get device model information
  Future<String> getDeviceModel() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      
      if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return '${iosInfo.name} (${iosInfo.systemVersion})';
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return '${androidInfo.manufacturer} ${androidInfo.model}';
      }
      
      return 'Unknown Device';
    } catch (e) {
      debugPrint('⚠️ Device model error: $e');
      return 'Unknown Device';
    }
  }
  
  /// Check if device has depth sensor capability
  Future<bool> hasDepthSensor() async {
    final capability = await detectDeviceCapability();
    return capability == DeviceCapability.lidarIOS || 
           capability == DeviceCapability.arcoreAndroid;
  }
  
  /// Get recommended scan quality based on device
  String getRecommendedQuality() {
    if (_cachedCapability == DeviceCapability.lidarIOS) {
      return 'high'; // LiDAR provides best quality
    } else if (_cachedCapability == DeviceCapability.arcoreAndroid) {
      return 'medium'; // ARCore provides good quality
    } else {
      return 'basic'; // Camera fallback
    }
  }
  
  /// Clear cached capability (for testing)
  void clearCache() {
    _cachedCapability = null;
  }

  /// Get AR capability level (LiDAR, ARKit, or Camera)
  Future<String> getARCapabilityLevel() async {
    if (_arCapabilityLevel != null) {
      return _arCapabilityLevel!;
    }
    
    await detectDeviceCapability();
    return _arCapabilityLevel ?? 'Unknown';
  }

  /// Check if device is iPhone 7 or newer
  Future<bool> isSupportediPhone() async {
    try {
      if (!Platform.isIOS) return false;
      
      final deviceModel = await getDeviceModel();
      final modelLower = deviceModel.toLowerCase();
      
      // iPhone 7 and newer
      return modelLower.contains('iphone 7') ||
             modelLower.contains('iphone 8') ||
             modelLower.contains('iphone x') ||
             modelLower.contains('iphone xs') ||
             modelLower.contains('iphone xr') ||
             modelLower.contains('iphone 1') ||
             modelLower.contains('iphone 14') ||
             modelLower.contains('iphone 15');
    } catch (e) {
      debugPrint('⚠️ iPhone model check error: $e');
      return false;
    }
  }

  /// Get recommended features based on device capability
  Map<String, dynamic> getRecommendedFeatures() {
    final features = <String, dynamic>{
      'autoCapture': false,
      'depthSensing': false,
      'raycast': false,
      'meshRendering': false,
      'exportFormat': 'OBJ',
    };

    switch (_cachedCapability) {
      case DeviceCapability.lidarIOS:
        features['autoCapture'] = true;
        features['depthSensing'] = true;
        features['raycast'] = true;
        features['meshRendering'] = true;
        features['exportFormat'] = 'USDZ';
        features['quality'] = 'high';
        break;
      case DeviceCapability.arkitIOS:
        features['autoCapture'] = true;
        features['depthSensing'] = false;
        features['raycast'] = true;
        features['meshRendering'] = true;
        features['exportFormat'] = 'OBJ';
        features['quality'] = 'medium';
        break;
      case DeviceCapability.arcoreAndroid:
        features['autoCapture'] = true;
        features['depthSensing'] = true;
        features['raycast'] = true;
        features['meshRendering'] = true;
        features['exportFormat'] = 'OBJ';
        features['quality'] = 'medium';
        break;
      case DeviceCapability.cameraFallback:
      default:
        features['autoCapture'] = false;
        features['depthSensing'] = false;
        features['raycast'] = false;
        features['meshRendering'] = false;
        features['exportFormat'] = 'OBJ';
        features['quality'] = 'basic';
        break;
    }

    return features;
  }
}
