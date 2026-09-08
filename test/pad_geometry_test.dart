import 'package:compasstorch/widgets/pad_geometry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const line = PadGeometry.line;
  const band = PadGeometry.maxBand;

  group('encendido y apagado', () {
    test('dentro del cuadro de reposo los dos están apagados', () {
      expect(PadGeometry.torchOn(PadGeometry.rest.dy), isFalse);
      expect(PadGeometry.beaconOn(PadGeometry.rest.dx), isFalse);
    });

    test('cruzar la línea horizontal hacia arriba enciende la linterna', () {
      expect(PadGeometry.torchOn(line + 0.01), isFalse);
      expect(PadGeometry.torchOn(line - 0.01), isTrue);
    });

    test('cruzar la línea vertical hacia la izquierda activa el faro', () {
      expect(PadGeometry.beaconOn(line + 0.01), isFalse);
      expect(PadGeometry.beaconOn(line - 0.01), isTrue);
    });
  });

  group('linterna: cruzar da el mínimo y subir sube la intensidad', () {
    test('nada más cruzar la línea está al mínimo', () {
      expect(
        PadGeometry.torchIntensity(line - 0.01),
        closeTo(PadGeometry.minTorchIntensity, 0.001),
      );
    });

    test('en toda la banda pegada a la línea sigue al mínimo', () {
      expect(
        PadGeometry.torchIntensity(line - band + 0.01),
        closeTo(PadGeometry.minTorchIntensity, 0.001),
      );
    });

    test('subir más allá de la banda la va subiendo', () {
      final justAbove = PadGeometry.torchIntensity(line - band - 0.05);
      final higher = PadGeometry.torchIntensity(line - band - 0.2);

      expect(justAbove, greaterThan(PadGeometry.minTorchIntensity));
      expect(higher, greaterThan(justAbove));
      expect(higher, lessThan(1));
    });

    test('arriba del todo queda al 100 %', () {
      expect(PadGeometry.torchIntensity(0), 1);
      expect(PadGeometry.torchIntensity(band), 1);
    });

    test('apagada por debajo de la línea', () {
      expect(PadGeometry.torchIntensity(line + 0.01), 0);
    });

    test('los dos ejes suben al alejarse de su línea', () {
      // Es la coherencia entre los dos controles: misma distancia a la línea,
      // mismo sentido de la gradación.
      double torchAt(double distance) =>
          PadGeometry.torchIntensity(line - distance);
      double beaconAt(double distance) =>
          PadGeometry.beaconLevel(line - distance);

      for (final (near, far) in [(0.1, 0.3), (0.3, 0.5)]) {
        expect(
          torchAt(far),
          greaterThan(torchAt(near)),
          reason: 'linterna de $near a $far',
        );
        expect(
          beaconAt(far),
          greaterThan(beaconAt(near)),
          reason: 'faro de $near a $far',
        );
      }
    });
  });

  group('faro: cruzar da el mínimo y seguir a la izquierda sube el brillo', () {
    test('nada más cruzar la línea el brillo es casi nulo', () {
      expect(PadGeometry.beaconLevel(line - 0.01), lessThan(0.05));
    });

    test('hacia la izquierda el brillo sube', () {
      final near = PadGeometry.beaconLevel(line - 0.1);
      final far = PadGeometry.beaconLevel(line - 0.3);

      expect(far, greaterThan(near));
    });

    test('en la banda izquierda está al 100 %', () {
      expect(PadGeometry.beaconLevel(band), 1);
      expect(PadGeometry.beaconLevel(band / 2), 1);
      expect(PadGeometry.beaconLevel(0), 1);
    });
  });

  group('ida y vuelta entre posición y nivel', () {
    test('la intensidad del flash se recupera desde su posición', () {
      for (final intensity in [0.1, 0.25, 0.5, 0.75, 1.0]) {
        final axis = PadGeometry.torchAxisFor(intensity);
        expect(
          PadGeometry.torchIntensity(axis),
          closeTo(intensity, 0.001),
          reason: 'intensidad $intensity',
        );
      }
    });

    test('el brillo del faro se recupera desde su posición', () {
      for (final level in [0.0, 0.25, 0.5, 0.75, 1.0]) {
        final axis = PadGeometry.beaconAxisFor(level);
        expect(
          PadGeometry.beaconLevel(axis),
          closeTo(level, 0.001),
          reason: 'nivel $level',
        );
      }
    });
  });

  group('al soltar la marca', () {
    Offset settle(Offset at, {bool gradual = true}) =>
        PadGeometry.settle(at, torchIsGradual: gradual);

    test('dentro del cuadro vuelve al centro del reposo', () {
      expect(settle(const Offset(0.95, 0.95)), PadGeometry.rest);
      expect(settle(const Offset(0.72, 0.99)), PadGeometry.rest);
    });

    test('en la banda izquierda se centra en ella', () {
      expect(settle(const Offset(0.02, 0.4)).dx, PadGeometry.beaconFullAxis);
    });

    test('en la banda del mínimo de la linterna se centra en ella', () {
      expect(settle(Offset(0.4, line - 0.02)).dy, PadGeometry.torchDimAxis);
    });

    test('en la banda del 100 % de la linterna se centra en ella', () {
      expect(settle(const Offset(0.4, 0.02)).dy, PadGeometry.torchFullAxis);
    });

    test('a media altura se queda donde se ha soltado', () {
      const released = Offset(0.35, 0.25);
      expect(settle(released), released);
    });

    test('cada eje se resuelve por su cuenta', () {
      // Arriba, pero horizontalmente dentro del reposo: linterna sí, faro no.
      final settled = settle(const Offset(0.9, 0.2));
      expect(settled.dx, PadGeometry.rest.dx);
      expect(settled.dy, 0.2);
    });

    test('sin gradación la marca se queda nada más pasada la línea', () {
      final settled = settle(const Offset(0.9, 0.2), gradual: false);
      expect(settled.dy, PadGeometry.torchDimAxis);
    });
  });
}
