import 'package:flutter/services.dart';

/// Lo que el dispositivo puede hacer con el flash.
class TorchCapabilities {
  const TorchCapabilities({required this.available, required this.gradual});

  /// El dispositivo tiene flash utilizable como linterna.
  final bool available;

  /// La intensidad se puede regular. En iOS es así siempre que haya flash; en
  /// Android hace falta Android 13 o superior y que la cámara declare más de un
  /// nivel, cosa que muchos modelos no hacen.
  final bool gradual;

  static const none = TorchCapabilities(available: false, gradual: false);
}

/// Acceso al canal nativo de la linterna, implementado en Kotlin y Swift dentro
/// de la propia aplicación (`TorchController`).
class TorchChannel {
  const TorchChannel();

  static const MethodChannel _channel = MethodChannel(
    'com.jgermade.compasstorch/torch',
  );

  Future<TorchCapabilities> capabilities() async {
    final response = await _channel.invokeMapMethod<String, dynamic>(
      'capabilities',
    );
    if (response == null) return TorchCapabilities.none;
    return TorchCapabilities(
      available: response['available'] as bool? ?? false,
      gradual: response['gradual'] as bool? ?? false,
    );
  }

  /// Enciende o apaga el flash. [intensity] va de 0 a 1 y solo se tiene en
  /// cuenta cuando el dispositivo permite regularla.
  Future<void> setTorch({required bool enabled, required double intensity}) {
    return _channel.invokeMethod<void>('setTorch', {
      'enabled': enabled,
      'intensity': intensity.clamp(0.0, 1.0),
    });
  }
}
