import Flutter
import UIKit
import CoreLocation

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: "com.garradigital.app/social_area",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "resolveSocialArea" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let args = call.arguments as? [String: Any],
            let latitudeNumber = args["latitude"] as? NSNumber,
            let longitudeNumber = args["longitude"] as? NSNumber else {
        result(nil)
        return
      }
      let latitude = latitudeNumber.doubleValue
      let longitude = longitudeNumber.doubleValue
      guard
            latitude.isFinite, longitude.isFinite,
            latitude >= -90, latitude <= 90,
            longitude >= -180, longitude <= 180 else {
        result(nil)
        return
      }
      let geocoder = CLGeocoder()
      geocoder.reverseGeocodeLocation(
        CLLocation(latitude: latitude, longitude: longitude)
      ) { [geocoder] placemarks, _ in
        _ = geocoder
        let place = placemarks?.first
        let label = [place?.subLocality, place?.locality,
                     place?.subAdministrativeArea, place?.administrativeArea]
          .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
          .first { !$0.isEmpty }
        result(label)
      }
    }
  }
}
