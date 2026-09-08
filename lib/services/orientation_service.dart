import 'dart:async';
import 'dart:math' as math;

import 'package:sensors_plus/sensors_plus.dart';

/// Cómo se está sujetando el teléfono.
enum DevicePose {
  /// Tumbado, con la pantalla mirando hacia arriba: se lee como una brújula.
  flat,

  /// Levantado, apuntando hacia delante: se lee como una regla de rumbos.
  upright,
}

/// Una lectura completa de la orientación del dispositivo.
class OrientationReading {
  const OrientationReading({
    required this.headingTop,
    required this.headingCamera,
    required this.elevation,
    required this.tilt,
  });

  /// Rumbo magnético (0-360°, 0 = norte) hacia el que mira el borde superior
  /// del teléfono. Es el valor útil con el teléfono tumbado.
  final double headingTop;

  /// Rumbo magnético (0-360°) hacia el que apunta la parte trasera del
  /// teléfono. Es el valor útil con el teléfono levantado.
  final double headingCamera;

  /// Elevación sobre el horizonte, en grados, de la dirección a la que apunta
  /// la parte trasera del teléfono. Negativa si apunta hacia el suelo.
  final double elevation;

  /// Inclinación del plano del teléfono: 0° tumbado, 90° vertical.
  final double tilt;

  /// Rumbo que corresponde a la postura indicada.
  double headingFor(DevicePose pose) =>
      pose == DevicePose.flat ? headingTop : headingCamera;
}

/// Fuente de lecturas de orientación.
abstract class OrientationService {
  Stream<OrientationReading> get readings;
}

/// Deriva la orientación combinando acelerómetro y magnetómetro.
///
/// Reproduce el cálculo de `SensorManager.getRotationMatrix` de Android: con el
/// vector de gravedad y el del campo magnético se construye la matriz de
/// rotación del dispositivo respecto al mundo (X = este, Y = norte magnético,
/// Z = arriba) y de ahí se extraen los rumbos.
///
/// El norte que se obtiene es el **magnético**; no se aplica declinación, así
/// que puede diferir unos grados del norte geográfico según la zona.
class SensorOrientationService implements OrientationService {
  SensorOrientationService({
    Stream<AccelerometerEvent>? accelerometer,
    Stream<MagnetometerEvent>? magnetometer,
  }) : _accelerometer =
           accelerometer ??
           accelerometerEventStream(samplingPeriod: SensorInterval.uiInterval),
       _magnetometer =
           magnetometer ??
           magnetometerEventStream(samplingPeriod: SensorInterval.uiInterval);

  /// Peso de cada nueva muestra en el filtro paso bajo. Valores pequeños dan
  /// una aguja más estable pero más lenta.
  static const double _gravitySmoothing = 0.15;
  static const double _fieldSmoothing = 0.25;

  final Stream<AccelerometerEvent> _accelerometer;
  final Stream<MagnetometerEvent> _magnetometer;

  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<MagnetometerEvent>? _magnetometerSubscription;
  StreamController<OrientationReading>? _controller;

  _Vector3? _gravity;
  _Vector3? _field;

  @override
  Stream<OrientationReading> get readings {
    final controller = _controller ??=
        StreamController<OrientationReading>.broadcast(
          onListen: _start,
          onCancel: _stop,
        );
    return controller.stream;
  }

  void _start() {
    _accelerometerSubscription = _accelerometer.listen((event) {
      _gravity = _lowPass(
        _gravity,
        _Vector3(event.x, event.y, event.z),
        _gravitySmoothing,
      );
    });
    _magnetometerSubscription = _magnetometer.listen((event) {
      _field = _lowPass(
        _field,
        _Vector3(event.x, event.y, event.z),
        _fieldSmoothing,
      );
      _emit();
    });
  }

  Future<void> _stop() async {
    await _accelerometerSubscription?.cancel();
    await _magnetometerSubscription?.cancel();
    _accelerometerSubscription = null;
    _magnetometerSubscription = null;
    _gravity = null;
    _field = null;
  }

  void _emit() {
    final reading = _computeReading(_gravity, _field);
    if (reading != null && _controller?.isClosed == false) {
      _controller!.add(reading);
    }
  }

  /// Libera las suscripciones y cierra el stream.
  Future<void> dispose() async {
    await _stop();
    await _controller?.close();
    _controller = null;
  }

  static _Vector3 _lowPass(_Vector3? previous, _Vector3 sample, double alpha) {
    if (previous == null) return sample;
    return _Vector3(
      previous.x + (sample.x - previous.x) * alpha,
      previous.y + (sample.y - previous.y) * alpha,
      previous.z + (sample.z - previous.z) * alpha,
    );
  }

  /// Construye la lectura a partir de los vectores de gravedad y campo
  /// magnético. Devuelve `null` si los vectores no permiten orientar (caída
  /// libre, o teléfono apuntando justo a lo largo de las líneas de campo).
  static OrientationReading? _computeReading(
    _Vector3? gravity,
    _Vector3? field,
  ) {
    if (gravity == null || field == null) return null;

    final gravityNorm = gravity.length;
    if (gravityNorm < 0.1) return null;
    final a = gravity / gravityNorm;

    // H = campo x gravedad -> apunta al este.
    final h = field.cross(a);
    final hNorm = h.length;
    if (hNorm < 0.1) return null;
    final east = h / hNorm;

    // M = gravedad x este -> apunta al norte magnético.
    final north = a.cross(east);

    // Filas de la matriz de rotación: este, norte, arriba (en ejes del
    // dispositivo). Para un vector v del dispositivo, su versión en el mundo es
    // (este·v, norte·v, arriba·v).
    final topBearing = _bearing(east.y, north.y);
    final cameraBearing = _bearing(-east.z, -north.z);
    final elevation = _degrees(math.asin(_clampUnit(-a.z)));
    final tilt = _degrees(math.acos(_clampUnit(a.z)));

    return OrientationReading(
      headingTop: topBearing,
      headingCamera: cameraBearing,
      elevation: elevation,
      tilt: tilt,
    );
  }

  /// Rumbo en grados 0-360 de un vector (este, norte).
  static double _bearing(double east, double north) {
    final degrees = _degrees(math.atan2(east, north));
    return (degrees + 360) % 360;
  }

  static double _degrees(double radians) => radians * 180 / math.pi;

  static double _clampUnit(double value) => value.clamp(-1.0, 1.0).toDouble();
}

/// Vector de tres componentes, lo justo para el cálculo de la orientación.
class _Vector3 {
  const _Vector3(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;

  double get length => math.sqrt(x * x + y * y + z * z);

  _Vector3 operator /(double scalar) =>
      _Vector3(x / scalar, y / scalar, z / scalar);

  _Vector3 cross(_Vector3 other) => _Vector3(
    y * other.z - z * other.y,
    z * other.x - x * other.z,
    x * other.y - y * other.x,
  );
}

/// Construye una lectura a partir de vectores brutos `[x, y, z]`. Devuelve
/// `null` si falta alguno o si no permiten orientar. Expuesto para los tests.
OrientationReading? readingFromVectors({
  required List<double>? gravity,
  required List<double>? magneticField,
}) {
  return SensorOrientationService._computeReading(
    gravity == null ? null : _Vector3(gravity[0], gravity[1], gravity[2]),
    magneticField == null
        ? null
        : _Vector3(magneticField[0], magneticField[1], magneticField[2]),
  );
}
