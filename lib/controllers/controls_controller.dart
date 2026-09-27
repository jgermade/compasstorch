import 'package:flutter/foundation.dart';

import '../services/device_services.dart';
import '../services/haptics.dart';
import '../services/selfie_camera.dart';
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

/// Motivo del último fallo de un control. El texto que ve la persona depende
/// del idioma, así que el controlador solo dice qué ha pasado y la pantalla se
/// encarga de traducirlo.
enum ControlsError {
  /// No se ha podido encender la linterna: sin flash o lo usa otra aplicación.
  torchUnavailable,

  /// No se ha podido apagar la linterna.
  torchOffFailed,

  /// El modo faro no ha podido ajustar el brillo o el bloqueo de pantalla.
  beaconPartial,
}

/// Estado de los dos controles del mando deslizable.
///
/// - Eje vertical: la linterna, con intensidad regulable donde el dispositivo
///   lo permita.
/// - Eje horizontal: el "modo faro", que pasa la interfaz a tema claro, sube el
///   brillo y mantiene la pantalla encendida.
///
/// Con [camera] la linterna sigue funcionando mientras el espejo tiene abierta
/// la cámara principal, que es la del flash: ver [SelfieCamera.holdsFlash].
class ControlsController extends ChangeNotifier {
  ControlsController(this._services, {SelfieCamera? camera})
    : _camera = camera,
      _cameraHoldsFlash = camera?.holdsFlash ?? false {
    _torchSender = _LatestValueSender(
      (value) => _sendTorch(enabled: true, intensity: value),
    );
    _brightnessSender = _LatestValueSender(
      (value) =>
          _services.setBrightness(enabled: true, level: _screenFor(value)),
    );
    camera?.addListener(_onCameraChanged);
  }

  /// Brillo mínimo del modo faro. No baja de aquí a propósito: con la pantalla
  /// apagada del todo no se vería el mando para volver a subirla.
  static const double minBeaconBrightness = 0.3;

  final DeviceServices _services;

  /// El espejo. Con la cámara principal abierta, el flash es suyo.
  final SelfieCamera? _camera;

  /// Lo que valía [SelfieCamera.holdsFlash] la última vez que se miró.
  bool _cameraHoldsFlash;

  late final _LatestValueSender _torchSender;
  late final _LatestValueSender _brightnessSender;

  bool _torchOn = false;
  bool _beaconOn = false;
  double _torchIntensity = 1;
  double _beaconLevel = 1;
  bool _keepAwake = true;
  ControlsError? _error;
  bool _disposed = false;

  TorchCapabilities _capabilities = TorchCapabilities.none;
  bool _capabilitiesLoaded = false;

  bool get torchOn => _torchOn;
  bool get beaconOn => _beaconOn;

  /// La aplicación impide que la pantalla se apague sola. Viene activado: se
  /// usa a oscuras, con las manos ocupadas y sin tocar la pantalla en un rato.
  bool get keepAwake => _keepAwake;

  /// Si la pantalla debe quedarse encendida ahora mismo. El modo faro la
  /// necesita encendida aunque la inhibición general esté desactivada.
  bool get _screenStaysOn => _keepAwake || _beaconOn;

  /// Intensidad de la linterna pedida, de 0 a 1.
  double get torchIntensity => _torchIntensity;

  /// Nivel de luz del modo faro, de 0 a 1.
  double get beaconLevel => _beaconLevel;

  /// El dispositivo permite regular la intensidad del flash. Mientras no se
  /// consulte al canal nativo se asume que no.
  bool get torchIsGradual => _capabilities.gradual;

  /// Último error de plataforma sin mostrar. Se consume con [takeError].
  ControlsError? get error => _error;

  /// Devuelve el error pendiente y lo borra, para no repetir el aviso.
  ControlsError? takeError() {
    final error = _error;
    _error = null;
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

    var sent = false;
    try {
      await loadTorchCapabilities();
      if (enabled && !_capabilities.available) {
        throw StateError('sin flash');
      }
      sent = true;
      await _sendTorch(enabled: enabled, intensity: _torchIntensity);
    } catch (error) {
      _torchOn = !enabled;
      _error = enabled
          ? ControlsError.torchUnavailable
          : ControlsError.torchOffFailed;
      _notify();
      if (sent) {
        // El lado nativo se queda con lo último que se le pide, para aplicarlo
        // en cuanto la cámara del flash quede libre: se le devuelve el estado
        // de antes, o haría más tarde lo que aquí se ha dado por fallido.
        try {
          await _services.setTorch(
            enabled: _torchOn,
            intensity: _torchIntensity,
          );
        } catch (error) {
          // Sigue ocupado: queda anotado igualmente.
        }
      }
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
      // Apagar el faro no destapa la pantalla si la inhibición general sigue
      // puesta, que es lo normal.
      await _services.setKeepScreenOn(enabled: _screenStaysOn);
    } catch (error) {
      _error = ControlsError.beaconPartial;
      _notify();
    }
  }

  /// Enciende o apaga la linterna desde la barra de estado, siempre al 100 %.
  ///
  /// El chip es el atajo: se toca para tener toda la luz de golpe, no para
  /// recuperar el nivel de antes. Graduar es lo que hace el mando, y ahí el
  /// nivel sigue estando donde se dejó. El mando se coloca solo donde toca.
  Future<void> toggleTorch() {
    if (_torchOn) return setTorch(enabled: false);
    return setTorch(enabled: true, intensity: 1);
  }

  /// Activa o desactiva el modo faro desde la barra de estado, también al
  /// 100 %, para que los dos chips se comporten igual.
  Future<void> toggleBeacon() {
    if (_beaconOn) return setBeacon(enabled: false);
    return setBeacon(enabled: true, level: 1);
  }

  /// Aplica la inhibición del apagado de pantalla. Es idempotente: se llama al
  /// arrancar y al volver del segundo plano, donde el sistema la ha soltado.
  Future<void> applyKeepAwake() async {
    try {
      await _services.setKeepScreenOn(enabled: _screenStaysOn);
    } catch (error) {
      // Sin bloqueo de pantalla la aplicación sigue funcionando igual.
    }
  }

  /// Cambia si la pantalla puede apagarse sola. Se maneja manteniendo pulsado
  /// el cuadro de reposo del mando, así que el golpe háptico es la única
  /// confirmación que se nota sin mirar.
  Future<void> toggleKeepAwake() async {
    _keepAwake = !_keepAwake;
    _notify();
    await _pulse(_keepAwake ? HapticCue.turnedOn : HapticCue.turnedOff);
    await applyKeepAwake();
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
    await applyKeepAwake();
    if (!_beaconOn) return;
    try {
      await _services.setBrightness(
        enabled: true,
        level: _screenFor(_beaconLevel),
      );
    } catch (error) {
      // Un fallo al restaurar no debe interrumpir la vuelta a la aplicación.
    }
  }

  /// Deja el dispositivo como estaba antes de cerrar la aplicación.
  Future<void> restoreDefaults() async {
    try {
      if (_torchOn) {
        await _sendTorch(enabled: false, intensity: _torchIntensity);
      }
      if (_beaconOn) {
        await _services.setBrightness(enabled: false, level: 1);
      }
      await _services.setKeepScreenOn(enabled: false);
    } catch (error) {
      // Se está cerrando: no hay nada que informar.
    }
    _torchOn = false;
    _beaconOn = false;
  }

  /// Manda el estado de la linterna al dispositivo.
  ///
  /// Va siempre primero al canal nativo, que se queda con lo pedido aunque no
  /// pueda aplicarlo. Si falla porque el espejo tiene abierta la cámara del
  /// flash —en Android no se puede tocar desde fuera mientras tanto—, se
  /// enciende o se apaga a través de esa misma cámara, sin graduar.
  Future<void> _sendTorch({
    required bool enabled,
    required double intensity,
  }) async {
    try {
      await _services.setTorch(enabled: enabled, intensity: intensity);
    } catch (error) {
      final camera = _camera;
      if (camera == null || !camera.holdsFlash) rethrow;
      await camera.setTorch(enabled: enabled);
    }
  }

  /// Abrir o soltar la cámara del flash lo apaga sin avisar. Si la linterna
  /// estaba encendida se vuelve a encender por el camino que toque ahora, para
  /// que siga como dice la barra.
  void _onCameraChanged() {
    final holds = _camera!.holdsFlash;
    if (holds == _cameraHoldsFlash) return;
    _cameraHoldsFlash = holds;
    // Si la cámara todavía no se ha cerrado del todo, el canal nativo lo
    // aplicará él solo en cuanto se cierre.
    if (_torchOn) _torchSender.submit(_torchIntensity);
  }

  /// Brillo real de la pantalla para un nivel del mando.
  double _screenFor(double level) =>
      minBeaconBrightness + level * (1 - minBeaconBrightness);

  /// Tic al entrar o salir de una banda de iluminación, mucho más suave que el
  /// golpe de encendido.
  Future<void> pulseZoneChange() => _pulse(HapticCue.zoneChanged);

  /// Toque al centrarse la burbuja de nivel: así se nota que el teléfono está
  /// horizontal sin apartar la vista de lo que se está apuntando.
  Future<void> pulseLevelled() => _pulse(HapticCue.levelled);

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
    _camera?.removeListener(_onCameraChanged);
    super.dispose();
  }
}
