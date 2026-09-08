import 'package:flutter/foundation.dart';

import '../services/device_services.dart';

/// Estado de los dos controles del mando deslizable.
///
/// - Eje vertical: la linterna (flash).
/// - Eje horizontal: el "modo faro", que pasa la interfaz a tema claro, sube el
///   brillo al máximo y mantiene la pantalla encendida.
class ControlsController extends ChangeNotifier {
  ControlsController(this._services);

  final DeviceServices _services;

  bool _torchOn = false;
  bool _beaconOn = false;
  String? _errorMessage;
  bool _disposed = false;

  bool get torchOn => _torchOn;
  bool get beaconOn => _beaconOn;

  /// Último error de plataforma sin mostrar. Se consume con [takeError].
  String? get errorMessage => _errorMessage;

  /// Devuelve el error pendiente y lo borra, para no repetir el aviso.
  String? takeError() {
    final error = _errorMessage;
    _errorMessage = null;
    return error;
  }

  Future<void> setTorch({required bool enabled}) async {
    if (_torchOn == enabled) return;
    _torchOn = enabled;
    _notify();
    try {
      if (enabled && !await _services.isTorchAvailable()) {
        throw StateError('sin flash');
      }
      await _services.setTorch(enabled: enabled);
    } catch (error) {
      _torchOn = !enabled;
      _errorMessage = enabled
          ? 'No se ha podido encender la linterna: este dispositivo no tiene '
              'flash disponible o lo está usando otra aplicación.'
          : 'No se ha podido apagar la linterna.';
      _notify();
    }
  }

  Future<void> setBeacon({required bool enabled}) async {
    if (_beaconOn == enabled) return;
    _beaconOn = enabled;
    _notify();
    try {
      await _services.setMaxBrightness(enabled: enabled);
      await _services.setKeepScreenOn(enabled: enabled);
    } catch (error) {
      _errorMessage = 'El modo faro se ha activado solo en parte: el sistema no '
          'ha permitido ajustar el brillo o mantener la pantalla encendida.';
      _notify();
    }
  }

  /// Vuelve a aplicar los ajustes de pantalla al regresar del segundo plano:
  /// el sistema restaura el brillo de la aplicación cuando esta se oculta.
  Future<void> reapplyScreenSettings() async {
    if (!_beaconOn) return;
    try {
      await _services.setMaxBrightness(enabled: true);
      await _services.setKeepScreenOn(enabled: true);
    } catch (error) {
      // Un fallo al restaurar no debe interrumpir la vuelta a la aplicación.
    }
  }

  /// Deja el dispositivo como estaba antes de cerrar la aplicación.
  Future<void> restoreDefaults() async {
    try {
      if (_torchOn) await _services.setTorch(enabled: false);
      if (_beaconOn) {
        await _services.setMaxBrightness(enabled: false);
        await _services.setKeepScreenOn(enabled: false);
      }
    } catch (error) {
      // Se está cerrando: no hay nada que informar.
    }
    _torchOn = false;
    _beaconOn = false;
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
