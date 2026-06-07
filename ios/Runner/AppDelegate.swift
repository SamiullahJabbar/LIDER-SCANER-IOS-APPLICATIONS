// ============================================================================
// AppDelegate.swift
// Registers ARKit (LiDARScannerPlugin) + RealityKit (RealityKitScenePlugin)
// ============================================================================

import UIKit
import Flutter
import ARKit
import RealityKit

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        let controller = window?.rootViewController as! FlutterViewController

        if #available(iOS 15.0, *) {
            // ── ARKit plugin (depth, raycasts, scanning) ──────────────
            LiDARScannerPlugin.register(
                with: self.registrar(forPlugin: "LiDARScannerPlugin")!
            )
            // ── RealityKit plugin (3D scene, mesh, pins, export) ──────
            RealityKitScenePlugin.register(
                with: self.registrar(forPlugin: "RealityKitScenePlugin")!
            )

        } else if #available(iOS 14.0, *) {
            // iOS 14: ARKit only, no RealityKit 2
            LiDARScannerPlugin.register(
                with: self.registrar(forPlugin: "LiDARScannerPlugin")!
            )
            // RealityKit fallback channel
            let rkFallback = FlutterMethodChannel(
                name: "com.lidarscanner/realitykit",
                binaryMessenger: controller.binaryMessenger
            )
            rkFallback.setMethodCallHandler { (call, result) in
                switch call.method {
                case "isRealityKitSupported":
                    result(false)
                default:
                    result(FlutterError(
                        code: "UNSUPPORTED",
                        message: "iOS 15+ required for RealityKit 2",
                        details: nil
                    ))
                }
            }

        } else {
            // Pre-iOS 14: neither ARKit LiDAR nor RealityKit
            for channelName in ["com.lidarscanner/native",
                                 "com.lidarscanner/realitykit"] {
                let ch = FlutterMethodChannel(
                    name: channelName,
                    binaryMessenger: controller.binaryMessenger
                )
                ch.setMethodCallHandler { (call, result) in
                    switch call.method {
                    case "isLiDARAvailable", "isDepthSupported",
                         "isARCoreSupported", "isRealityKitSupported":
                        result(false)
                    default:
                        result(FlutterError(
                            code: "UNSUPPORTED",
                            message: "iOS 14+ required",
                            details: nil
                        ))
                    }
                }
            }
        }

        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}
