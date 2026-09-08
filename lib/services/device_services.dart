import 'package:screen_brightness/screen_brightness.dart';
import 'package:torch_light/torch_light.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Acceso a las capacidades del dispositivo que usa la aplicación.
///
/// Se declara como interfaz para poder sustituirla por un doble en los tests,
/// donde los canales de plataforma no están disponibles.
abstract class DeviceServices {
  /// `true` si el dispositivo tiene flash utilizable como linterna.
  Future<bool> isTorchAvailable();

  /// Enciende o apaga el flash.
  Future<void> setTorch({required bool enabled});

  /// Lleva el brillo de la pantalla al máximo, o lo devuelve al del sistema.
  Future<void> setMaxBrightness({required bool enabled});

  /// Impide (o vuelve a permitir) que la pantalla se apague sola.
  Future<void> setKeepScreenOn({required bool enabled});
}

/// Implementación real sobre los plugins de plataforma.
class PlatformDeviceServices implements DeviceServices {
  const PlatformDeviceServices();

  @override
  Future<bool> isTorchAvailable() => TorchLight.isTorchAvailable();

  @override
  Future<void> setTorch({required bool enabled}) {
    return enabled ? TorchLight.enableTorch() : TorchLight.disableTorch();
  }

  @override
  Future<void> setMaxBrightness({required bool enabled}) {
    final brightness = ScreenBrightness.instance;
    return enabled
        ? brightness.setApplicationScreenBrightness(1)
        : brightness.resetApplicationScreenBrightness();
  }

  @override
  Future<void> setKeepScreenOn({required bool enabled}) {
    return WakelockPlus.toggle(enable: enabled);
  }
}
