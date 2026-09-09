import 'dart:math' as math;

import 'package:compasstorch/widgets/compass_dial.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const span = CompassDial.levelSpan;

  group('la gota de nivel se queda dentro de la tapa', () {
    test('sin inclinación descansa en el centro', () {
      expect(CompassDial.levelShift(0, 0), Offset.zero);
    });

    test('se va hacia el lado que se levanta', () {
      // Inclinar a la derecha (x positiva) manda la gota a la derecha; el eje
      // vertical va al revés que el de la pantalla.
      expect(CompassDial.levelShift(span / 2, 0).dx, closeTo(0.5, 1e-9));
      expect(CompassDial.levelShift(0, span / 2).dy, closeTo(-0.5, 1e-9));
    });

    test('dentro del recorrido la inclinación se traslada tal cual', () {
      final shift = CompassDial.levelShift(span * 0.3, span * 0.4);
      expect(shift.distance, closeTo(0.5, 1e-9));
    });

    test('al borde del recorrido llega justo al borde, sin pasarse', () {
      expect(CompassDial.levelShift(span, 0).distance, closeTo(1, 1e-9));
    });

    test('en diagonal no se sale por las esquinas', () {
      // El caso que fallaba: acotando cada eje por su cuenta, una inclinación
      // en diagonal daba (1, 1), que está a raíz de dos del centro.
      final shift = CompassDial.levelShift(span, span);
      expect(shift.distance, closeTo(1, 1e-9));
      expect(shift.dx, closeTo(math.sqrt1_2, 1e-9));
      expect(shift.dy, closeTo(-math.sqrt1_2, 1e-9));
    });

    test('por mucho que se incline, nunca pasa del borde', () {
      for (var grados = 0; grados < 360; grados += 5) {
        final rumbo = grados * math.pi / 180;
        for (final exceso in [1.0, 1.5, 4.0, 40.0]) {
          final shift = CompassDial.levelShift(
            span * exceso * math.cos(rumbo),
            span * exceso * math.sin(rumbo),
          );
          expect(
            shift.distance,
            lessThanOrEqualTo(1 + 1e-9),
            reason: 'a $grados° con $exceso veces el recorrido',
          );
        }
      }
    });

    test('pasado el borde conserva la dirección', () {
      final dentro = CompassDial.levelShift(span * 0.3, span * 0.4);
      final fuera = CompassDial.levelShift(span * 3, span * 4);
      expect(fuera.distance, closeTo(1, 1e-9));
      expect(fuera.dx, closeTo(dentro.dx / dentro.distance, 1e-9));
      expect(fuera.dy, closeTo(dentro.dy / dentro.distance, 1e-9));
    });
  });
}
