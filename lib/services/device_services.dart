import 'package:flutter/services.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'haptics.dart';
import 'torch_channel.dart';

/// Acceso a las capacidades del dispositivo que usa la aplicación.
///
/// Se declara como interfaz para poder sustituirla por un doble en los tests,
/// donde los canales de plataforma no están disponibles.
abstract class DeviceServices {
  /// Qué puede hacer el dispositivo con el flash: si lo tiene y si permite
  /// regular la intensidad.
  Future<TorchCapabilities> torchCapabilities();

  /// Enciende o apaga el flash. [intensity] va de 0 a 1 y el lado nativo la
  /// ignora en los dispositivos que solo admiten encendido y apagado.
  Future<void> setTorch({required bool enabled, required double intensity});

  /// Fija el brillo de la pantalla para esta aplicación, o lo devuelve al del
  /// sistema. [level] va de 0 a 1 y no tiene limitaciones de plataforma: es un
  /// atributo de la ventana, no del hardware.
  Future<void> setBrightness({required bool enabled, required double level});

  /// Impide (o vuelve a permitir) que la pantalla se apague sola.
  Future<void> setKeepScreenOn({required bool enabled});

  /// Aviso háptico. Cada [HapticCue] tiene su propia fuerza, para poder
  /// distinguir los avisos sin mirar la pantalla.
  Future<void> haptic(HapticCue cue);
}

/// Implementación real sobre los plugins de plataforma.
class PlatformDeviceServices implements DeviceServices {
  const PlatformDeviceServices({this.torch = const TorchChannel()});

  final TorchChannel torch;

  @override
  Future<TorchCapabilities> torchCapabilities() => torch.capabilities();

  @override
  Future<void> setTorch({required bool enabled, required double intensity}) {
    return torch.setTorch(enabled: enabled, intensity: intensity);
  }

  @override
  Future<void> setBrightness({required bool enabled, required double level}) {
    final brightness = ScreenBrightness.instance;
    return enabled
        ? brightness.setApplicationScreenBrightness(level.clamp(0.0, 1.0))
        : brightness.resetApplicationScreenBrightness();
  }

  @override
  Future<void> setKeepScreenOn({required bool enabled}) {
    return WakelockPlus.toggle(enable: enabled);
  }

  @override
  Future<void> haptic(HapticCue cue) {
    return switch (cue) {
      HapticCue.turnedOn => HapticFeedback.heavyImpact(),
      HapticCue.turnedOff => HapticFeedback.mediumImpact(),
      HapticCue.levelled => HapticFeedback.lightImpact(),
      HapticCue.zoneChanged => HapticFeedback.selectionClick(),
    };
  }
}
