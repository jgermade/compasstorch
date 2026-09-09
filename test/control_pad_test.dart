import 'package:compasstorch/widgets/control_pad.dart';
import 'package:compasstorch/widgets/pad_geometry.dart';
import 'package:flutter/gestures.dart';
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
  double torchLevel = 0;
  double beaconLevel = 0;
  int zoneChanges = 0;
  bool keepAwake = true;
  int keepAwakeToggles = 0;

  /// Enciende la linterna desde fuera del mando, como hace el chip de la barra
  /// de estado.
  void switchTorchOn(double level) {
    setState(() {
      torch = true;
      torchLevel = level;
    });
  }

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
              keepAwake: keepAwake,
              onTorchChanged: (enabled, level) => setState(() {
                torch = widget.rejectTorch ? false : enabled;
                torchLevel = level;
              }),
              onBeaconChanged: (enabled, level) => setState(() {
                beacon = enabled;
                beaconLevel = level;
              }),
              onZoneChanged: () => zoneChanges++,
              onToggleKeepAwake: () => setState(() {
                keepAwake = !keepAwake;
                keepAwakeToggles++;
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

  /// Posición normalizada de la marca, tal y como la está pintando el mando.
  /// El pintor es privado, así que se le pregunta sin tipo.
  Offset markOf(WidgetTester tester) {
    final paint = tester.widget<CustomPaint>(
      find.descendant(
        of: find.byType(ControlPad),
        matching: find.byType(CustomPaint),
      ),
    );
    return ((paint.painter as dynamic).mark as Offset);
  }

  /// Punto del mando en coordenadas normalizadas.
  Offset at(WidgetTester tester, double x, double y) {
    final rect = tester.getRect(padFinder());
    return rect.topLeft + Offset(rect.width * x, rect.height * y);
  }

  /// Arrastra la marca de un punto normalizado a otro.
  ///
  /// El reconocedor de arrastre descarta los primeros [kPanSlop] píxeles antes
  /// de empezar a informar, así que se consumen aparte: si no, el gesto llega
  /// corto y la marca no alcanza la línea.
  Future<void> dragMark(WidgetTester tester, Offset from, Offset to) async {
    final start = at(tester, from.dx, from.dy);
    final delta = at(tester, to.dx, to.dy) - start;
    final gesture = await tester.startGesture(start);
    final slop = delta.distance == 0
        ? const Offset(0, -kPanSlop - 1)
        : delta / delta.distance * (kPanSlop + 1);
    await gesture.moveBy(slop);
    await tester.pump();
    // Por pasos, como un arrastre real: de un solo salto la marca se saltaría
    // las bandas intermedias.
    const steps = 12;
    for (var i = 0; i < steps; i++) {
      await gesture.moveBy(delta / steps.toDouble());
      await tester.pump();
    }
    await gesture.up();
    await tester.pumpAndSettle();
  }

  /// Arrastra la marca desde el reposo hasta un punto normalizado.
  Future<void> dragMarkTo(WidgetTester tester, double x, double y) =>
      dragMark(tester, PadGeometry.rest, Offset(x, y));

  testWidgets('en reposo los dos controles están apagados', (tester) async {
    await tester.pumpWidget(const _Harness());
    await tester.pumpAndSettle();

    expect(state(tester).torch, isFalse);
    expect(state(tester).beacon, isFalse);
  });

  testWidgets('cruzar la línea hacia arriba enciende la linterna al mínimo', (
    tester,
  ) async {
    await tester.pumpWidget(const _Harness());

    // Justo por encima de la línea horizontal: dentro de la banda del mínimo.
    await dragMarkTo(tester, PadGeometry.rest.dx, PadGeometry.line - 0.05);

    expect(state(tester).torch, isTrue);
    expect(
      state(tester).torchLevel,
      closeTo(PadGeometry.minTorchIntensity, 0.001),
    );
    expect(state(tester).beacon, isFalse);
  });

  testWidgets('seguir subiendo sube la intensidad de la linterna', (
    tester,
  ) async {
    await tester.pumpWidget(const _Harness());

    await dragMarkTo(tester, PadGeometry.rest.dx, 0.35);
    final middle = state(tester).torchLevel;

    await dragMarkTo(tester, PadGeometry.rest.dx, 0.05);

    expect(middle, greaterThan(PadGeometry.minTorchIntensity));
    expect(middle, lessThan(1));
    expect(state(tester).torchLevel, greaterThan(middle));
    expect(state(tester).torchLevel, closeTo(1, 0.001));
    expect(state(tester).torch, isTrue);
  });

  testWidgets('cruzar hacia la izquierda activa el faro con poco brillo', (
    tester,
  ) async {
    await tester.pumpWidget(const _Harness());

    await dragMarkTo(tester, PadGeometry.line - 0.05, PadGeometry.rest.dy);

    expect(state(tester).beacon, isTrue);
    expect(state(tester).beaconLevel, lessThan(0.05));
    expect(state(tester).torch, isFalse);
  });

  testWidgets('seguir hacia la izquierda sube el brillo hasta el 100 %', (
    tester,
  ) async {
    await tester.pumpWidget(const _Harness());

    await dragMarkTo(tester, 0.35, PadGeometry.rest.dy);
    final middle = state(tester).beaconLevel;

    await dragMarkTo(tester, 0.04, PadGeometry.rest.dy);

    expect(middle, greaterThan(0));
    expect(middle, lessThan(1));
    expect(state(tester).beaconLevel, closeTo(1, 0.001));
  });

  testWidgets('en diagonal quedan los dos activos', (tester) async {
    await tester.pumpWidget(const _Harness());

    await dragMarkTo(tester, 0.3, 0.3);

    expect(state(tester).torch, isTrue);
    expect(state(tester).beacon, isTrue);
  });

  testWidgets('soltar dentro del cuadro devuelve la marca al reposo', (
    tester,
  ) async {
    await tester.pumpWidget(const _Harness());

    await dragMarkTo(tester, PadGeometry.rest.dx, PadGeometry.line - 0.05);
    expect(state(tester).torch, isTrue);

    // Desde donde ha quedado la marca, de vuelta al cuadro de reposo.
    await dragMark(
      tester,
      Offset(PadGeometry.rest.dx, PadGeometry.torchDimAxis),
      PadGeometry.rest,
    );

    expect(state(tester).torch, isFalse);
    expect(state(tester).beacon, isFalse);
  });

  testWidgets('un arrastre corto dentro del cuadro no enciende nada', (
    tester,
  ) async {
    await tester.pumpWidget(const _Harness());

    await dragMarkTo(tester, 0.78, 0.78);

    expect(state(tester).torch, isFalse);
    expect(state(tester).beacon, isFalse);
  });

  testWidgets('sin gradación la linterna se queda en el 100 %', (tester) async {
    await tester.pumpWidget(const _Harness(torchIsGradual: false));

    // Aunque se suelte arriba del todo, donde habría atenuación.
    await dragMarkTo(tester, PadGeometry.rest.dx, 0.05);

    expect(state(tester).torch, isTrue);
    expect(state(tester).torchLevel, closeTo(1, 0.001));
  });

  testWidgets('cambiar de banda avisa con un tic háptico', (tester) async {
    await tester.pumpWidget(const _Harness());

    // De la banda del máximo al tramo continuo, y de ahí a la del mínimo.
    await dragMarkTo(tester, PadGeometry.rest.dx, 0.05);

    expect(state(tester).zoneChanges, greaterThan(0));
  });

  testWidgets('quedarse dentro del cuadro no avisa de cambios de banda', (
    tester,
  ) async {
    await tester.pumpWidget(const _Harness());

    await dragMarkTo(tester, 0.8, 0.8);

    expect(state(tester).zoneChanges, 0);
  });

  testWidgets('tocar un punto lleva la marca hasta él', (tester) async {
    await tester.pumpWidget(const _Harness());

    await tester.tapAt(at(tester, 0.05, 0.05));
    await tester.pumpAndSettle();

    // Esquina superior izquierda: los dos al máximo.
    expect(state(tester).beacon, isTrue);
    expect(state(tester).beaconLevel, closeTo(1, 0.001));
    expect(state(tester).torch, isTrue);
    expect(state(tester).torchLevel, closeTo(1, 0.001));
  });

  testWidgets('si el padre rechaza la linterna, la marca vuelve al reposo', (
    tester,
  ) async {
    await tester.pumpWidget(const _Harness(rejectTorch: true));

    await dragMarkTo(tester, PadGeometry.rest.dx, PadGeometry.line - 0.05);

    expect(state(tester).torch, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('encender desde fuera del mando desplaza la marca', (
    tester,
  ) async {
    await tester.pumpWidget(const _Harness());
    await tester.pumpAndSettle();
    expect(markOf(tester).dy, closeTo(PadGeometry.rest.dy, 0.001));

    // Como al tocar el chip de la linterna en la barra de estado.
    state(tester).switchTorchOn(1);
    await tester.pumpAndSettle();

    expect(markOf(tester).dy, closeTo(PadGeometry.torchFullAxis, 0.001));
    expect(markOf(tester).dx, closeTo(PadGeometry.rest.dx, 0.001));
  });

  group('bloqueo del apagado de pantalla', () {
    testWidgets('mantener pulsado el cuadro de reposo lo cambia', (
      tester,
    ) async {
      await tester.pumpWidget(const _Harness());
      await tester.pumpAndSettle();

      final gesture = await tester.startGesture(
        at(tester, PadGeometry.rest.dx, PadGeometry.rest.dy),
      );
      // Un poco más de la cuenta: el reconocedor de toques no informa de que
      // el dedo ha bajado hasta que el arrastre pierde el turno.
      await tester.pump(
        ControlPad.holdToKeepAwake + const Duration(seconds: 1),
      );
      expect(state(tester).keepAwakeToggles, 1);
      expect(state(tester).keepAwake, isFalse);

      await gesture.up();
      await tester.pumpAndSettle();

      // El dedo se ha gastado en el ajuste: no ha encendido ninguna luz.
      expect(state(tester).torch, isFalse);
      expect(state(tester).beacon, isFalse);
    });

    testWidgets('soltar antes de tiempo no cambia nada', (tester) async {
      await tester.pumpWidget(const _Harness());
      await tester.pumpAndSettle();

      final gesture = await tester.startGesture(
        at(tester, PadGeometry.rest.dx, PadGeometry.rest.dy),
      );
      await tester.pump(const Duration(seconds: 2));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(state(tester).keepAwakeToggles, 0);
    });

    testWidgets('mantener pulsado fuera del reposo no lo cambia', (
      tester,
    ) async {
      await tester.pumpWidget(const _Harness());
      await tester.pumpAndSettle();

      // Arriba a la izquierda: ahí el dedo sí manda sobre las luces.
      final gesture = await tester.startGesture(at(tester, 0.1, 0.1));
      // Un poco más de la cuenta: el reconocedor de toques no informa de que
      // el dedo ha bajado hasta que el arrastre pierde el turno.
      await tester.pump(
        ControlPad.holdToKeepAwake + const Duration(seconds: 1),
      );
      await gesture.up();
      await tester.pumpAndSettle();

      expect(state(tester).keepAwakeToggles, 0);
    });

    testWidgets('arrastrar no dispara la pulsación larga', (tester) async {
      await tester.pumpWidget(const _Harness());

      await dragMarkTo(tester, PadGeometry.rest.dx, 0.05);
      await tester.pump(ControlPad.holdToKeepAwake);

      expect(state(tester).keepAwakeToggles, 0);
    });

    testWidgets('sin bloqueo los iconos del mando se ven en gris', (
      tester,
    ) async {
      await tester.pumpWidget(const _Harness());
      await tester.pumpAndSettle();

      Color iconColor(IconData icon) =>
          tester.widget<Icon>(find.byIcon(icon)).color!;

      expect(
        HSLColor.fromColor(iconColor(Icons.flashlight_on)).saturation,
        greaterThan(0),
      );

      final gesture = await tester.startGesture(
        at(tester, PadGeometry.rest.dx, PadGeometry.rest.dy),
      );
      // Un poco más de la cuenta: el reconocedor de toques no informa de que
      // el dedo ha bajado hasta que el arrastre pierde el turno.
      await tester.pump(
        ControlPad.holdToKeepAwake + const Duration(seconds: 1),
      );
      await gesture.up();
      await tester.pumpAndSettle();

      expect(HSLColor.fromColor(iconColor(Icons.flashlight_on)).saturation, 0);
      expect(
        HSLColor.fromColor(iconColor(Icons.brightness_high)).saturation,
        0,
      );
    });
  });
}
