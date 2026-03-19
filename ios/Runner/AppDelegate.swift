import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // Register LiDAR Scanner Plugin
    if #available(iOS 14.0, *) {
        let controller = window?.rootViewController as! FlutterViewController
        LiDARScannerPlugin.register(with: registrar(forPlugin: "LiDARScannerPlugin")!)
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
