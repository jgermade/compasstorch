import 'package:compasstorch/widgets/control_pad.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Envoltorio con estado, como lo usa la pantalla real: el mando es controlado
/// y refleja el estado que le devuelve el padre.
class _Harness extends StatefulWidget {
  const _Harness({this.rejectTorch = false, this.torchIsGradual = true});

  /// Simula un dispositivo sin flash: el padre no acepta encender la linterna.
  final bool rejectTorch;

  /// Simula un dispositivo que no puede regular la intensidad del flash.
  final bool torchIsGradual;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  bool torch = false;
  bool beacon = false;
  double torchLevel = 1;
  double beaconLevel = 1;

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
              torchIntensity: torchLevel,
              beaconLevel: beaconLevel,
              torchIsGradual: widget.torchIsGradual,
              onTorchChanged: (enabled, level) => setState(() {
                torch = widget.rejectTorch ? false : enabled;
                torchLevel = level;
              }),
              onBeaconChanged: (enabled, level) => setState(() {
                beacon = enabled;
                beaconLevel = level;
              }),
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

  testWidgets('arrastrar hacia la izquierda activa el modo faro', (
    tester,
  ) async {
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

  testWidgets('devolver el pulsador al reposo apaga la linterna', (
    tester,
  ) async {
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

  testWidgets('tocar una esquina lleva el pulsador a ese estado', (
    tester,
  ) async {
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

  testWidgets('soltar a media altura enciende la linterna a media potencia', (
    tester,
  ) async {
    await tester.pumpWidget(const _Harness());
    final rect = tester.getRect(padFinder());

    // Hasta la mitad del recorrido vertical.
    await tester.dragFrom(restingKnob(tester), Offset(0, -rect.height * 0.45));
    await tester.pumpAndSettle();

    final state = tester.state<_HarnessState>(find.byType(_Harness));
    expect(state.torch, isTrue);
    // Ni apagada ni a tope: un valor intermedio.
    expect(state.torchLevel, greaterThan(0.15));
    expect(state.torchLevel, lessThan(0.85));
  });

  testWidgets('más arriba da más intensidad que menos arriba', (tester) async {
    await tester.pumpWidget(const _Harness());
    final rect = tester.getRect(padFinder());
    final state = tester.state<_HarnessState>(find.byType(_Harness));

    await tester.dragFrom(restingKnob(tester), Offset(0, -rect.height * 0.3));
    await tester.pumpAndSettle();
    final low = state.torchLevel;

    await tester.dragFrom(restingKnob(tester), Offset(0, -rect.height * 0.9));
    await tester.pumpAndSettle();

    expect(state.torchLevel, greaterThan(low));
  });

  testWidgets('el eje horizontal gradúa el brillo del faro', (tester) async {
    await tester.pumpWidget(const _Harness());
    final rect = tester.getRect(padFinder());
    final state = tester.state<_HarnessState>(find.byType(_Harness));

    await tester.dragFrom(restingKnob(tester), Offset(-rect.width * 0.45, 0));
    await tester.pumpAndSettle();

    expect(state.beacon, isTrue);
    expect(state.beaconLevel, greaterThan(0.15));
    expect(state.beaconLevel, lessThan(0.85));
  });

  testWidgets('sin gradación el eje vertical vuelve a ser un interruptor', (
    tester,
  ) async {
    await tester.pumpWidget(const _Harness(torchIsGradual: false));
    final rect = tester.getRect(padFinder());
    final state = tester.state<_HarnessState>(find.byType(_Harness));

    await tester.dragFrom(restingKnob(tester), Offset(0, -rect.height * 0.45));
    await tester.pumpAndSettle();

    expect(state.torch, isTrue);
    // El pulsador salta arriba del todo en vez de quedarse a media altura.
    expect(state.torchLevel, closeTo(1, 0.001));
  });

  testWidgets('un arrastre por debajo del umbral no llega a encender', (
    tester,
  ) async {
    await tester.pumpWidget(const _Harness());
    final rect = tester.getRect(padFinder());

    await tester.dragFrom(restingKnob(tester), Offset(0, -rect.height * 0.05));
    await tester.pumpAndSettle();

    expect(tester.state<_HarnessState>(find.byType(_Harness)).torch, isFalse);
  });

  testWidgets('si el padre rechaza la linterna, el pulsador vuelve al reposo', (
    tester,
  ) async {
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
