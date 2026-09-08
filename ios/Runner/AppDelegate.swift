import AVFoundation
import Flutter
import UIKit

/// Canal de plataforma para la linterna, con intensidad regulable.
///
/// `setTorchModeOn(level:)` acepta un nivel continuo entre
/// `minAvailableTorchLevel` y `maxAvailableTorchLevel` desde iOS 6, así que en
/// iOS la gradación está siempre disponible cuando hay flash. El hardware puede
/// redondearla a unos pocos escalones.
final class TorchController {
  private static let channelName = "com.jgermade.compasstorch/torch"

  private let channel: FlutterMethodChannel

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: Self.channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  /// Cámara con flash utilizable como linterna.
  private var torchDevice: AVCaptureDevice? {
    guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else {
      return nil
    }
    return device
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "capabilities":
      let available = torchDevice != nil
      result(["available": available, "gradual": available])
    case "setTorch":
      setTorch(call, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func setTorch(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let arguments = call.arguments as? [String: Any] ?? [:]
    let enabled = arguments["enabled"] as? Bool ?? false
    let intensity = min(max(arguments["intensity"] as? Double ?? 1.0, 0.0), 1.0)

    guard let device = torchDevice else {
      result(
        FlutterError(
          code: "torch_unavailable",
          message: "El dispositivo no tiene flash.",
          details: nil))
      return
    }

    do {
      try device.lockForConfiguration()
      defer { device.unlockForConfiguration() }

      if enabled {
        // `setTorchModeOn(level:)` admite el intervalo (0, 1]: un nivel de 0
        // lanzaría una excepción en vez de apagar la linterna, y el máximo es
        // 1. Se acotan con literales a propósito, porque `AVCaptureDevice` no
        // expone ninguna constante para el mínimo.
        let level = min(max(Float(intensity), 0.01), 1)
        try device.setTorchModeOn(level: level)
      } else {
        device.torchMode = .off
      }
      result(nil)
    } catch {
      result(
        FlutterError(
          code: "torch_failed",
          message: error.localizedDescription,
          details: nil))
    }
  }
}

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var torch: TorchController?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    torch = TorchController(messenger: engineBridge.applicationRegistrar.messenger())
  }
}
