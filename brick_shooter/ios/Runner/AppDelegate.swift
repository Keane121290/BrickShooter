import Flutter
import UIKit
import AppTrackingTransparency

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var trackingReady = false

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    setupTrackingChannel()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    setupTrackingChannel()
  }

  /// Flutter calls this only after the first frame and the UMP consent flow.
  private func setupTrackingChannel() {
    guard !trackingReady,
          let controller = window?.rootViewController as? FlutterViewController else {
      return
    }
    trackingReady = true
    let channel = FlutterMethodChannel(
      name: "brick_shooter/tracking",
      binaryMessenger: controller.binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "requestTrackingAuthorization" else {
        result(FlutterMethodNotImplemented)
        return
      }
      DispatchQueue.main.async {
        let status = ATTrackingManager.trackingAuthorizationStatus
        guard status == .notDetermined else {
          result(Int(status.rawValue))
          return
        }
        ATTrackingManager.requestTrackingAuthorization { updatedStatus in
          DispatchQueue.main.async {
            result(Int(updatedStatus.rawValue))
          }
        }
      }
    }
  }
}
