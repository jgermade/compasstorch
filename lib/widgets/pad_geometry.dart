import 'dart:ui' show Offset, lerpDouble;

/// Tramo del recorrido en el que está la marca, para un eje.
enum PadZone {
  /// Dentro del cuadro de reposo: el control está apagado.
  rest,

  /// Banda de iluminación mínima.
  min,

  /// Tramo continuo entre las dos bandas.
  ramp,

  /// Banda de iluminación máxima.
  max,
}

/// Geometría del mando, en coordenadas normalizadas del cuadro: (0,0) es la
/// esquina superior izquierda y (1,1) la inferior derecha.
///
/// Dos líneas blancas cruzan el control y delimitan un cuadro de reposo en la
/// esquina inferior derecha, donde descansa la marca. Cruzar la línea
/// horizontal hacia arriba enciende la linterna; cruzar la vertical hacia la
/// izquierda activa el modo faro. Los dos ejes son independientes.
///
/// Cada eje tiene una banda pegada a su línea y otra en el borde opuesto, pero
/// el sentido está invertido a propósito:
///
/// - **Linterna**: cruzar la línea da el 100 %, que es lo que se quiere de una
///   linterna nada más encenderla. Seguir subiendo la atenúa hasta el mínimo,
///   en la banda del borde superior.
/// - **Faro**: cruzar la línea da el mínimo y seguir hacia la izquierda sube el
///   brillo, hasta el 100 % en la banda del borde izquierdo.
class PadGeometry {
  const PadGeometry._();

  /// Posición de las dos líneas blancas. Cuanto más cerca de 1, más pequeño es
  /// el cuadro de reposo.
  static const double line = 0.70;

  /// Anchura de las cuatro bandas de iluminación.
  static const double maxBand = 0.18;

  /// Intensidad del flash en la banda superior, la más atenuada.
  static const double minTorchIntensity = 0.1;

  /// Centro del cuadro de reposo.
  static const Offset rest = Offset((line + 1) / 2, (line + 1) / 2);

  /// Recorrido continuo entre las dos bandas de un eje.
  static const double _ramp = line - 2 * maxBand;

  /// Altura a la que la marca deja la linterna al 100 %.
  static const double torchFullAxis = line - maxBand / 2;

  /// Altura a la que la marca deja la linterna al mínimo.
  static const double torchDimAxis = maxBand / 2;

  /// Posición horizontal a la que la marca deja el faro al 100 %.
  static const double beaconFullAxis = maxBand / 2;

  /// Posición horizontal a la que la marca deja el faro al mínimo.
  static const double beaconDimAxis = line - maxBand / 2;

  static bool torchOn(double y) => y < line;

  static bool beaconOn(double x) => x < line;

  /// Tramo en el que cae la marca en el eje de la linterna.
  static PadZone torchZone(double y) {
    if (y >= line) return PadZone.rest;
    if (y >= line - maxBand) return PadZone.max;
    if (y <= maxBand) return PadZone.min;
    return PadZone.ramp;
  }

  /// Tramo en el que cae la marca en el eje del faro.
  static PadZone beaconZone(double x) {
    if (x >= line) return PadZone.rest;
    if (x >= line - maxBand) return PadZone.min;
    if (x <= maxBand) return PadZone.max;
    return PadZone.ramp;
  }

  /// Intensidad del flash (0 a 1) para una altura de la marca.
  static double torchIntensity(double y) {
    switch (torchZone(y)) {
      case PadZone.rest:
        return 0;
      case PadZone.max:
        return 1;
      case PadZone.min:
        return minTorchIntensity;
      case PadZone.ramp:
        final fraction = (line - maxBand - y) / _ramp;
        return lerpDouble(1, minTorchIntensity, fraction.clamp(0.0, 1.0))!;
    }
  }

  /// Brillo del faro (0 a 1) para una posición horizontal de la marca.
  static double beaconLevel(double x) {
    switch (beaconZone(x)) {
      case PadZone.rest:
      case PadZone.min:
        return 0;
      case PadZone.max:
        return 1;
      case PadZone.ramp:
        return ((line - maxBand - x) / _ramp).clamp(0.0, 1.0);
    }
  }

  /// Altura de la marca que corresponde a una intensidad de flash.
  static double torchAxisFor(double intensity) {
    if (intensity >= 1) return torchFullAxis;
    if (intensity <= minTorchIntensity) return torchDimAxis;
    final fraction = (1 - intensity) / (1 - minTorchIntensity);
    return (line - maxBand) - fraction * _ramp;
  }

  /// Posición horizontal de la marca que corresponde a un brillo del faro.
  static double beaconAxisFor(double level) {
    if (level >= 1) return beaconFullAxis;
    if (level <= 0) return beaconDimAxis;
    return (line - maxBand) - level * _ramp;
  }

  /// Coloca la marca al soltarla.
  ///
  /// En el cuadro de reposo vuelve al centro, y en una banda de iluminación se
  /// centra en ella. En el tramo continuo se queda donde se ha soltado. Cada
  /// eje se resuelve por separado, así que soltar arriba a la derecha deja la
  /// linterna encendida y el faro en reposo.
  static Offset settle(Offset released, {required bool torchIsGradual}) {
    final double x;
    switch (beaconZone(released.dx)) {
      case PadZone.rest:
        x = rest.dx;
      case PadZone.max:
        x = beaconFullAxis;
      case PadZone.min:
        x = beaconDimAxis;
      case PadZone.ramp:
        x = released.dx;
    }

    final double y;
    if (!torchIsGradual && torchOn(released.dy)) {
      // Sin gradación la linterna solo tiene un nivel: la marca se queda en la
      // banda del 100 % en vez de a media altura.
      y = torchFullAxis;
    } else {
      switch (torchZone(released.dy)) {
        case PadZone.rest:
          y = rest.dy;
        case PadZone.max:
          y = torchFullAxis;
        case PadZone.min:
          y = torchDimAxis;
        case PadZone.ramp:
          y = released.dy;
      }
    }

    return Offset(x, y);
  }
}
