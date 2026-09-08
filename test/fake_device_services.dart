import 'package:compasstorch/services/device_services.dart';

/// Doble de [DeviceServices] para los tests: registra lo que se le pide y
/// permite simular fallos de plataforma.
class FakeDeviceServices implements DeviceServices {
  FakeDeviceServices({this.torchAvailable = true});

  bool torchAvailable;
  bool failOnTorch = false;
  bool failOnBrightness = false;

  /// Pulsos hápticos emitidos: `true` al activar, `false` al desactivar.
  final List<bool> haptics = [];

  bool torchOn = false;
  bool maxBrightness = false;
  bool keepScreenOn = false;
  final List<String> calls = [];

  @override
  Future<bool> isTorchAvailable() async {
    calls.add('isTorchAvailable');
    return torchAvailable;
  }

  @override
  Future<void> setTorch({required bool enabled}) async {
    calls.add('setTorch($enabled)');
    if (failOnTorch) throw Exception('flash no disponible');
    torchOn = enabled;
  }

  @override
  Future<void> setMaxBrightness({required bool enabled}) async {
    calls.add('setMaxBrightness($enabled)');
    if (failOnBrightness) throw Exception('brillo bloqueado');
    maxBrightness = enabled;
  }

  @override
  Future<void> setKeepScreenOn({required bool enabled}) async {
    calls.add('setKeepScreenOn($enabled)');
    keepScreenOn = enabled;
  }

  @override
  Future<void> hapticPulse({required bool activating}) async {
    calls.add('hapticPulse($activating)');
    haptics.add(activating);
  }
}
