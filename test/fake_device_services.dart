import 'package:compasstorch/services/device_services.dart';
import 'package:compasstorch/services/torch_channel.dart';

/// Doble de [DeviceServices] para los tests: registra lo que se le pide y
/// permite simular fallos de plataforma.
class FakeDeviceServices implements DeviceServices {
  FakeDeviceServices({this.torchAvailable = true, this.torchGradual = true});

  bool torchAvailable;

  /// El dispositivo simulado permite regular la intensidad del flash.
  bool torchGradual;

  bool failOnTorch = false;
  bool failOnBrightness = false;

  bool torchOn = false;
  bool keepScreenOn = false;

  /// Último nivel pedido a cada control, o `null` si está en reposo.
  double? torchIntensity;
  double? screenBrightness;

  /// Pulsos hápticos emitidos: `true` al activar, `false` al desactivar.
  final List<bool> haptics = [];

  /// Todos los niveles de intensidad que han llegado al "dispositivo".
  final List<double> torchLevels = [];
  final List<double> brightnessLevels = [];

  final List<String> calls = [];

  @override
  Future<TorchCapabilities> torchCapabilities() async {
    calls.add('torchCapabilities');
    return TorchCapabilities(
      available: torchAvailable,
      gradual: torchAvailable && torchGradual,
    );
  }

  @override
  Future<void> setTorch({
    required bool enabled,
    required double intensity,
  }) async {
    calls.add('setTorch($enabled, ${intensity.toStringAsFixed(2)})');
    if (failOnTorch) throw Exception('flash no disponible');
    torchOn = enabled;
    torchIntensity = enabled ? intensity : null;
    if (enabled) torchLevels.add(intensity);
  }

  @override
  Future<void> setBrightness({
    required bool enabled,
    required double level,
  }) async {
    calls.add('setBrightness($enabled, ${level.toStringAsFixed(2)})');
    if (failOnBrightness) throw Exception('brillo bloqueado');
    screenBrightness = enabled ? level : null;
    if (enabled) brightnessLevels.add(level);
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
