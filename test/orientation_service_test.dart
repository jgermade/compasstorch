import 'package:compasstorch/services/orientation_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Campo magnético terrestre en el mundo (este, norte, arriba): apunta al norte
/// y hacia abajo, como en el hemisferio norte.
const double hField = 20; // componente horizontal, µT
const double vField = 40; // componente vertical (hacia abajo), µT
const double g = 9.81;

void main() {
  group('teléfono tumbado', () {
    test('con la parte de arriba al norte, el rumbo es 0°', () {
      final reading = readingFromVectors(
        gravity: const [0, 0, g],
        magneticField: const [0, hField, -vField],
      )!;

      expect(reading.headingTop, closeTo(0, 0.5));
      expect(reading.tilt, closeTo(0, 0.5));
      // Tumbado, la cámara mira al suelo.
      expect(reading.elevation, closeTo(-90, 0.5));
    });

    test('girado 90°, el rumbo es este', () {
      final reading = readingFromVectors(
        gravity: const [0, 0, g],
        magneticField: const [-hField, 0, -vField],
      )!;

      expect(reading.headingTop, closeTo(90, 0.5));
    });

    test('girado 180°, el rumbo es sur', () {
      final reading = readingFromVectors(
        gravity: const [0, 0, g],
        magneticField: const [0, -hField, -vField],
      )!;

      expect(reading.headingTop, closeTo(180, 0.5));
    });

    test('girado 270°, el rumbo es oeste', () {
      final reading = readingFromVectors(
        gravity: const [0, 0, g],
        magneticField: const [hField, 0, -vField],
      )!;

      expect(reading.headingTop, closeTo(270, 0.5));
    });
  });

  group('teléfono levantado', () {
    test('apuntando al norte, el rumbo de la cámara es 0°', () {
      final reading = readingFromVectors(
        gravity: const [0, g, 0],
        magneticField: const [0, -vField, -hField],
      )!;

      expect(reading.headingCamera, closeTo(0, 0.5));
      expect(reading.tilt, closeTo(90, 0.5));
      expect(reading.elevation, closeTo(0, 0.5));
    });

    test('apuntando al este, el rumbo de la cámara es 90°', () {
      final reading = readingFromVectors(
        gravity: const [0, g, 0],
        magneticField: const [-hField, -vField, 0],
      )!;

      expect(reading.headingCamera, closeTo(90, 0.5));
    });
  });

  group('casos degenerados', () {
    test('sin lecturas todavía no hay orientación', () {
      expect(
        readingFromVectors(gravity: const [0, 0, g], magneticField: null),
        isNull,
      );
      expect(
        readingFromVectors(gravity: null, magneticField: const [0, 20, -40]),
        isNull,
      );
    });

    test('en caída libre no se puede orientar', () {
      expect(
        readingFromVectors(
          gravity: const [0, 0, 0],
          magneticField: const [0, hField, -vField],
        ),
        isNull,
      );
    });

    test('con el campo alineado con la gravedad no se puede orientar', () {
      expect(
        readingFromVectors(
          gravity: const [0, 0, g],
          magneticField: const [0, 0, -vField],
        ),
        isNull,
      );
    });
  });

  group('nivel', () {
    test('tumbado del todo, el nivel está centrado', () {
      final reading = readingFromVectors(
        gravity: const [0, 0, g],
        magneticField: const [0, hField, -vField],
      )!;

      expect(reading.levelX, closeTo(0, 0.001));
      expect(reading.levelY, closeTo(0, 0.001));
    });

    test('el nivel señala el lado que se levanta', () {
      // Lado derecho arriba: la componente X de la vertical es positiva.
      final right = readingFromVectors(
        gravity: const [g * 0.5, 0, g * 0.866],
        magneticField: const [0, hField, -vField],
      )!;
      expect(right.levelX, closeTo(0.5, 0.01));
      expect(right.levelY, closeTo(0, 0.01));

      // Borde de arriba levantado: le toca a la componente Y.
      final top = readingFromVectors(
        gravity: const [0, g * 0.5, g * 0.866],
        magneticField: const [0, hField, -vField],
      )!;
      expect(top.levelY, closeTo(0.5, 0.01));
      expect(top.levelX, closeTo(0, 0.01));
    });
  });

  test('la inclinación crece al levantar el teléfono', () {
    // 45°: la gravedad se reparte entre los ejes Y y Z.
    final reading = readingFromVectors(
      gravity: const [0, g * 0.7071, g * 0.7071],
      magneticField: const [0, hField, -vField],
    )!;

    expect(reading.tilt, closeTo(45, 0.5));
    expect(reading.elevation, closeTo(-45, 0.5));
  });
}
