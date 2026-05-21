import CallKit
import Flutter
import PushKit
import UIKit
import YandexMapsMobile
import flutter_callkit_incoming

@main
@objc class AppDelegate: FlutterAppDelegate, PKPushRegistryDelegate {

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    YMKMapKit.setApiKey("9bd1fb94-3024-43a3-9d31-44ecc894e42f")
    GeneratedPluginRegistrant.register(with: self)

    // PushKit registration for VoIP-style incoming-order notifications.
    let voipRegistry = PKPushRegistry(queue: .main)
    voipRegistry.delegate = self
    voipRegistry.desiredPushTypes = [.voIP]

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // MARK: - PKPushRegistryDelegate

  func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
    let token = pushCredentials.token.map { String(format: "%02x", $0) }.joined()
    SwiftFlutterCallkitIncomingPlugin.sharedInstance?.setDevicePushTokenVoIP(token)
  }

  func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
    SwiftFlutterCallkitIncomingPlugin.sharedInstance?.setDevicePushTokenVoIP("")
  }

  // iOS 13+ requires CXProvider.reportNewIncomingCall to be invoked within
  // a few seconds of receiving a VoIP push, otherwise the system will
  // disable VoIP for this app. flutter_callkit_incoming handles this for us
  // as long as we forward the push payload here.
  func pushRegistry(_ registry: PKPushRegistry,
                    didReceiveIncomingPushWith payload: PKPushPayload,
                    for type: PKPushType,
                    completion: @escaping () -> Void) {
    let data = payload.dictionaryPayload
    let orderId = (data["orderId"] as? String) ?? (data["id"] as? String) ?? UUID().uuidString
    let title = (data["title"] as? String) ?? "Yangi zakaz"
    let body = (data["body"] as? String) ?? ""

    let callKitData = flutter_callkit_incoming.Data(
      id: orderId,
      nameCaller: title,
      handle: body,
      type: 0
    )
    callKitData.extra = data as NSDictionary
    callKitData.appName = "Fondex Vendor"
    callKitData.iconName = "CallKitLogo"
    callKitData.normalHandleType = "generic"
    callKitData.supportsVideo = false
    callKitData.duration = 45000
    callKitData.textAccept = "Qabul qilish"
    callKitData.textDecline = "Rad etish"

    SwiftFlutterCallkitIncomingPlugin.sharedInstance?.showCallkitIncoming(callKitData, fromPushKit: true)
    completion()
  }
}
