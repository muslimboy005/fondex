import Flutter
import UIKit
import GoogleMaps
import YandexMapsMobile

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
   GMSServices.provideAPIKey("YOUR_API_KEY_HERE")
   YMKMapKit.setApiKey("9bd1fb94-3024-43a3-9d31-44ecc894e42f")
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
