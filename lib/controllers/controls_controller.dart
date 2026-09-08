import 'package:flutter/foundation.dart';

import '../services/device_services.dart';
import '../services/haptics.dart';
import '../services/torch_channel.dart';

/// Manda al canal nativo el último valor pedido, sin encolar los intermedios.
///
/// Arrastrar el mando genera decenas de cambios por segundo. En vez de mandarlos
/// todos, se guarda solo el más reciente y se envía en cuanto termina el envío
/// anterior: el dispositivo converge al valor final sin saturar el canal.
class _LatestValueSender {
  _LatestValueSender(this._send);

  final Future<void> Function(double value) _send;

  double? _pending;
  bool _busy = false;

  Future<void> submit(double value) async {
    _pending = value;
    if (_busy) return;

    _busy = true;
    while (_pending != null) {
      final next = _pending!;
      _pending = null;
      try {
        await _send(next);
      } catch (error) {
        // Un nivel rechazado no cambia el estado de encendido.
      }
    }
    _busy = false;
  }
}

/// Estado de los dos controles del mando deslizable.
///
/// - Eje vertical: la linterna, con intensidad regulable donde el dispositivo
///   lo permita.
/// - Eje horizontal: el "modo faro", que pasa la interfaz a tema claro, sube el
///   brillo y mantiene la pantalla encendida.
class ControlsController extends ChangeNotifier {
  ControlsController(this._services) {
    _torchSender = _LatestValueSender(
      (value) => _services.setTorch(enabled: true, intensity: value),
    );
    _brightnessSender = _LatestValueSender(
      (value) =>
          _services.setBrightness(enabled: true, level: _screenFor(value)),
    );
  }

  /// Brillo mínimo del modo faro. No baja de aquí a propósito: con la pantalla
  /// apagada del todo no se vería el mando para volver a subirla.
  static const double minBeaconBrightness = 0.3;

  final DeviceServices _services;

  late final _LatestValueSender _torchSender;
  late final _LatestValueSender _brightnessSender;

  bool _torchOn = false;
  bool _beaconOn = false;
  double _torchIntensity = 1;
  double _beaconLevel = 1;
  String? _errorMessage;
  bool _disposed = false;

  TorchCapabilities _capabilities = TorchCapabilities.none;
  bool _capabilitiesLoaded = false;

  bool get torchOn => _torchOn;
  bool get beaconOn => _beaconOn;

  /// Intensidad de la linterna pedida, de 0 a 1.
  double get torchIntensity => _torchIntensity;

  /// Nivel de luz del modo faro, de 0 a 1.
  double get beaconLevel => _beaconLevel;

  /// El dispositivo permite regular la intensidad del flash. Mientras no se
  /// consulte al canal nativo se asume que no.
  bool get torchIsGradual => _capabilities.gradual;

  /// Último error de plataforma sin mostrar. Se consume con [takeError].
  String? get errorMessage => _errorMessage;

  /// Devuelve el error pendiente y lo borra, para no repetir el aviso.
  String? takeError() {
    final error = _errorMessage;
    _errorMessage = null;
    return error;
  }

  /// Pregunta al dispositivo qué puede hacer con el flash. Es idempotente.
  Future<void> loadTorchCapabilities() async {
    if (_capabilitiesLoaded) return;
    _capabilitiesLoaded = true;
    try {
      _capabilities = await _services.torchCapabilities();
    } catch (error) {
      _capabilities = TorchCapabilities.none;
    }
    _notify();
  }

  /// Enciende o apaga la linterna. [intensity] solo se aplica donde se puede
  /// regular.
  Future<void> setTorch({required bool enabled, double? intensity}) async {
    if (intensity != null) {
      final clamped = intensity.clamp(0.0, 1.0);
      if (_torchIntensity != clamped) {
        _torchIntensity = clamped;
        _notify();
      }
    }

    if (_torchOn == enabled) {
      // Ya estaba en ese estado: solo cambia el nivel, y sin repetir la
      // vibración, que marca el encendido y el apagado y nada más.
      if (enabled) await _torchSender.submit(_torchIntensity);
      return;
    }

    _torchOn = enabled;
    _notify();

    try {
      await loadTorchCapabilities();
      if (enabled && !_capabilities.available) {
        throw StateError('sin flash');
      }
      await _services.setTorch(enabled: enabled, intensity: _torchIntensity);
    } catch (error) {
      _torchOn = !enabled;
      _errorMessage = enabled
          ? 'No se ha podido encender la linterna: este dispositivo no tiene '
                'flash disponible o lo está usando otra aplicación.'
          : 'No se ha podido apagar la linterna.';
      _notify();
      return;
    }

    // La vibración confirma solo lo que de verdad ha ocurrido: si el flash
    // falla, no se nota nada.
    await _pulse(enabled ? HapticCue.turnedOn : HapticCue.turnedOff);
  }

  /// Cambia la intensidad con la linterna ya encendida.
  Future<void> setTorchIntensity(double value) async {
    final clamped = value.clamp(0.0, 1.0);
    if (_torchIntensity != clamped) {
      _torchIntensity = clamped;
      _notify();
    }
    if (!_torchOn || !_capabilities.gradual) return;
    await _torchSender.submit(clamped);
  }

  /// Activa o desactiva el modo faro. [level] gradúa el brillo de la pantalla.
  Future<void> setBeacon({required bool enabled, double? level}) async {
    if (level != null) {
      final clamped = level.clamp(0.0, 1.0);
      if (_beaconLevel != clamped) {
        _beaconLevel = clamped;
        _notify();
      }
    }

    if (_beaconOn == enabled) {
      if (enabled) await _brightnessSender.submit(_beaconLevel);
      return;
    }

    _beaconOn = enabled;
    _notify();

    // El modo faro cambia el tema pase lo que pase con el brillo, así que el
    // golpe háptico va siempre.
    await _pulse(enabled ? HapticCue.turnedOn : HapticCue.turnedOff);

    try {
      await _services.setBrightness(
        enabled: enabled,
        level: _screenFor(_beaconLevel),
      );
      await _services.setKeepScreenOn(enabled: enabled);
    } catch (error) {
      _errorMessage =
          'El modo faro se ha activado solo en parte: el sistema no '
          'ha permitido ajustar el brillo o mantener la pantalla encendida.';
      _notify();
    }
  }

  /// Cambia el brillo con el modo faro ya activo.
  Future<void> setBeaconLevel(double value) async {
    final clamped = value.clamp(0.0, 1.0);
    if (_beaconLevel != clamped) {
      _beaconLevel = clamped;
      _notify();
    }
    if (!_beaconOn) return;
    await _brightnessSender.submit(clamped);
  }

  /// Vuelve a aplicar los ajustes de pantalla al regresar del segundo plano:
  /// el sistema restaura el brillo de la aplicación cuando esta se oculta.
  Future<void> reapplyScreenSettings() async {
    if (!_beaconOn) return;
    try {
      await _services.setBrightness(
        enabled: true,
        level: _screenFor(_beaconLevel),
      );
      await _services.setKeepScreenOn(enabled: true);
    } catch (error) {
      // Un fallo al restaurar no debe interrumpir la vuelta a la aplicación.
    }
  }

  /// Deja el dispositivo como estaba antes de cerrar la aplicación.
  Future<void> restoreDefaults() async {
    try {
      if (_torchOn) {
        await _services.setTorch(enabled: false, intensity: _torchIntensity);
      }
      if (_beaconOn) {
        await _services.setBrightness(enabled: false, level: 1);
        await _services.setKeepScreenOn(enabled: false);
      }
    } catch (error) {
      // Se está cerrando: no hay nada que informar.
    }
    _torchOn = false;
    _beaconOn = false;
  }

  /// Brillo real de la pantalla para un nivel del mando.
  double _screenFor(double level) =>
      minBeaconBrightness + level * (1 - minBeaconBrightness);

  /// Tic al entrar o salir de una banda de iluminación, mucho más suave que el
  /// golpe de encendido.
  Future<void> pulseZoneChange() => _pulse(HapticCue.zoneChanged);

  /// Vibración de confirmación. Un dispositivo sin motor háptico no es motivo
  /// para dar por fallado el cambio.
  Future<void> _pulse(HapticCue cue) async {
    try {
      await _services.haptic(cue);
    } catch (error) {
      // Sin háptica: el control ya ha cambiado igualmente.
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
