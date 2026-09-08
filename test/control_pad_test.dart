import 'package:compasstorch/widgets/control_pad.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Envoltorio con estado, como lo usa la pantalla real: el mando es controlado
/// y refleja el estado que le devuelve el padre.
class _Harness extends StatefulWidget {
  const _Harness({this.rejectTorch = false});

  /// Simula un dispositivo sin flash: el padre no acepta encender la linterna.
  final bool rejectTorch;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  bool torch = false;
  bool beacon = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 300,
            height: 300,
            child: ControlPad(
              torchOn: torch,
              beaconOn: beacon,
              onTorchChanged: (value) => setState(
                () => torch = widget.rejectTorch ? false : value,
              ),
              onBeaconChanged: (value) => setState(() => beacon = value),
            ),
          ),
        ),
      ),
    );
  }
}

void main() {
  /// Rectángulo real del mando: un cuadrado centrado dentro de su hueco.
  Finder padFinder() => find.descendant(
        of: find.byType(ControlPad),
        matching: find.byType(GestureDetector),
      );
  _HarnessState state(WidgetTester tester) =>
      tester.state<_HarnessState>(find.byType(_Harness));

  /// Centro del pulsador en reposo: esquina inferior derecha del mando.
  Offset restingKnob(WidgetTester tester) {
    final rect = tester.getRect(padFinder());
    final margin = rect.shortestSide * 0.16 + 8;
    return Offset(rect.right - margin, rect.bottom - margin);
  }

  testWidgets('arrastrar hacia arriba enciende la linterna', (tester) async {
    await tester.pumpWidget(const _Harness());
    final rect = tester.getRect(padFinder());

    await tester.dragFrom(restingKnob(tester), Offset(0, -rect.height * 0.7));
    await tester.pumpAndSettle();

    expect(state(tester).torch, isTrue);
    expect(state(tester).beacon, isFalse);
  });

  testWidgets('arrastrar hacia la izquierda activa el modo faro',
      (tester) async {
    await tester.pumpWidget(const _Harness());
    final rect = tester.getRect(padFinder());

    await tester.dragFrom(restingKnob(tester), Offset(-rect.width * 0.7, 0));
    await tester.pumpAndSettle();

    expect(state(tester).beacon, isTrue);
    expect(state(tester).torch, isFalse);
  });

  testWidgets('en diagonal se activan los dos a la vez', (tester) async {
    await tester.pumpWidget(const _Harness());
    final rect = tester.getRect(padFinder());

    await tester.dragFrom(
      restingKnob(tester),
      Offset(-rect.width * 0.7, -rect.height * 0.7),
    );
    await tester.pumpAndSettle();

    expect(state(tester).torch, isTrue);
    expect(state(tester).beacon, isTrue);
  });

  testWidgets('un arrastre corto no llega a activar nada', (tester) async {
    await tester.pumpWidget(const _Harness());

    await tester.dragFrom(restingKnob(tester), const Offset(0, -30));
    await tester.pumpAndSettle();

    expect(state(tester).torch, isFalse);
  });

  testWidgets('devolver el pulsador al reposo apaga la linterna',
      (tester) async {
    await tester.pumpWidget(const _Harness());
    final rect = tester.getRect(padFinder());

    await tester.dragFrom(restingKnob(tester), Offset(0, -rect.height * 0.7));
    await tester.pumpAndSettle();
    expect(state(tester).torch, isTrue);

    // El pulsador está ahora arriba a la derecha; se arrastra de vuelta.
    final raised = restingKnob(tester).translate(0, -rect.height * 0.7 + 16);
    await tester.dragFrom(raised, Offset(0, rect.height * 0.7));
    await tester.pumpAndSettle();

    expect(state(tester).torch, isFalse);
  });

  testWidgets('tocar una esquina lleva el pulsador a ese estado',
      (tester) async {
    await tester.pumpWidget(const _Harness());
    final rect = tester.getRect(padFinder());

    // Esquina superior izquierda: las dos funciones activas.
    await tester.tapAt(rect.topLeft + const Offset(24, 24));
    await tester.pumpAndSettle();

    expect(state(tester).torch, isTrue);
    expect(state(tester).beacon, isTrue);

    // Esquina inferior derecha: reposo.
    await tester.tapAt(rect.bottomRight - const Offset(24, 24));
    await tester.pumpAndSettle();

    expect(state(tester).torch, isFalse);
    expect(state(tester).beacon, isFalse);
  });

  testWidgets('si el padre rechaza la linterna, el pulsador vuelve al reposo',
      (tester) async {
    await tester.pumpWidget(const _Harness(rejectTorch: true));
    final rect = tester.getRect(padFinder());
    final home = restingKnob(tester);

    await tester.dragFrom(home, Offset(0, -rect.height * 0.7));
    await tester.pumpAndSettle();

    expect(state(tester).torch, isFalse);
    // Y el pulsador ha vuelto: tocarlo de nuevo vuelve a intentar encenderla.
    expect(tester.takeException(), isNull);
  });
}
