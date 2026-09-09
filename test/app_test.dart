import 'dart:async';

import 'package:compasstorch/main.dart';
import 'package:compasstorch/screens/home_screen.dart';
import 'package:compasstorch/services/haptics.dart';
import 'package:compasstorch/services/orientation_service.dart';
import 'package:compasstorch/widgets/compass_dial.dart';
import 'package:compasstorch/widgets/control_pad.dart';
import 'package:compasstorch/widgets/heading_ribbon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_device_services.dart';

class FakeOrientationService implements OrientationService {
  final _controller = StreamController<OrientationReading>.broadcast();

  @override
  Stream<OrientationReading> get readings => _controller.stream;

  void emit({
    required double tilt,
    double heading = 0,
    double elevation = 0,
    double levelX = 0,
    double levelY = 0,
  }) {
    _controller.add(
      OrientationReading(
        headingTop: heading,
        headingCamera: heading,
        elevation: elevation,
        tilt: tilt,
        levelX: levelX,
        levelY: levelY,
      ),
    );
  }

  void close() => _controller.close();
}

/// Rectángulo real del mando: es un cuadrado centrado dentro de su hueco.
Rect padRect(WidgetTester tester) => tester.getRect(
  find.descendant(
    of: find.byType(ControlPad),
    matching: find.byType(GestureDetector),
  ),
);

void main() {
  group('elección de vista según la inclinación', () {
    test('tumbado muestra la brújula', () {
      expect(poseFor(5, DevicePose.upright), DevicePose.flat);
    });

    test('levantado muestra la regla de rumbos', () {
      expect(poseFor(85, DevicePose.flat), DevicePose.upright);
    });

    test('en la zona intermedia se mantiene la vista actual', () {
      expect(poseFor(45, DevicePose.flat), DevicePose.flat);
      expect(poseFor(45, DevicePose.upright), DevicePose.upright);
    });
  });

  group('aplicación', () {
    late FakeDeviceServices services;
    late FakeOrientationService orientation;

    setUp(() {
      services = FakeDeviceServices();
      orientation = FakeOrientationService();
    });

    tearDown(() => orientation.close());

    Future<void> pumpApp(WidgetTester tester) async {
      await tester.pumpWidget(
        CompassTorchApp(services: services, orientation: orientation),
      );
      await tester.pump();
    }

    testWidgets('arranca con tema oscuro', (tester) async {
      await pumpApp(tester);

      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.theme!.brightness, Brightness.dark);
    });

    testWidgets('tumbado se ve la brújula; levantado, la regla de rumbos', (
      tester,
    ) async {
      await pumpApp(tester);

      orientation.emit(tilt: 5, heading: 42);
      await tester.pumpAndSettle();
      expect(find.byType(CompassDial), findsOneWidget);
      expect(find.byType(HeadingRibbon), findsNothing);

      orientation.emit(tilt: 80, heading: 42);
      await tester.pumpAndSettle();
      expect(find.byType(HeadingRibbon), findsOneWidget);
      expect(find.byType(CompassDial), findsNothing);
    });

    testWidgets('la barra de arriba lleva los mandos a las esquinas', (
      tester,
    ) async {
      await pumpApp(tester);
      orientation.emit(tilt: 5);
      await tester.pumpAndSettle();

      final beacon = tester.getCenter(find.byKey(const ValueKey('beaconChip')));
      final view = tester.getCenter(find.byIcon(Icons.explore_rounded));
      final torch = tester.getCenter(find.byKey(const ValueKey('torchChip')));
      final width = tester.getSize(find.byType(MaterialApp)).width;

      // Faro a la izquierda, linterna a la derecha y la vista en medio.
      expect(beacon.dx, lessThan(view.dx));
      expect(view.dx, lessThan(torch.dx));
      expect(view.dx, closeTo(width / 2, 1));
      // El nombre de la vista ya no se escribe: queda solo el icono.
      expect(find.textContaining('compass'), findsNothing);
    });

    testWidgets('la burbuja de nivel avisa cuando el teléfono está plano', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpApp(tester);

      orientation.emit(tilt: 1, levelX: 0.002, levelY: 0.002);
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Phone level'), findsOneWidget);

      orientation.emit(tilt: 8, levelX: 0.12, levelY: 0.02);
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Phone tilted'), findsOneWidget);

      semantics.dispose();
    });

    testWidgets('centrar la burbuja se confirma con un toque háptico', (
      tester,
    ) async {
      await pumpApp(tester);

      orientation.emit(tilt: 8, levelX: 0.10, levelY: 0);
      await tester.pumpAndSettle();
      expect(services.haptics, isEmpty);

      orientation.emit(tilt: 1, levelX: 0.005, levelY: 0);
      await tester.pumpAndSettle();
      expect(services.haptics, [HapticCue.levelled]);

      // Mientras siga nivelada no se repite, ni siquiera con el temblor de la
      // mano rondando el umbral.
      orientation.emit(tilt: 1, levelX: 0.001, levelY: 0.002);
      orientation.emit(tilt: 2, levelX: 0.025, levelY: 0);
      await tester.pumpAndSettle();
      expect(services.haptics, [HapticCue.levelled]);

      // Al salir del todo y volver, sí avisa otra vez.
      orientation.emit(tilt: 8, levelX: 0.10, levelY: 0);
      await tester.pumpAndSettle();
      orientation.emit(tilt: 1, levelX: 0.004, levelY: 0);
      await tester.pumpAndSettle();
      expect(services.haptics, [HapticCue.levelled, HapticCue.levelled]);
    });

    testWidgets('al arrancar con el teléfono ya plano no vibra sola', (
      tester,
    ) async {
      await pumpApp(tester);
      await tester.pumpAndSettle();
      // Todavía sin rumbo: se ve el aviso de calibración, no la burbuja.
      expect(services.haptics, isEmpty);

      // Y la primera lectura, con el teléfono plano encima de la mesa, no
      // cuenta como que se acabe de nivelar.
      orientation.emit(tilt: 1, levelX: 0.003, levelY: 0.001);
      await tester.pumpAndSettle();
      expect(services.haptics, isEmpty);
    });

    testWidgets('el modo faro pasa a tema claro y sube el brillo', (
      tester,
    ) async {
      await pumpApp(tester);
      orientation.emit(tilt: 5);
      await tester.pumpAndSettle();

      final pad = padRect(tester);
      // Se toca la mitad izquierda para llevar el pulsador al eje del faro.
      await tester.tapAt(Offset(pad.left + 24, pad.bottom - 24));
      await tester.pumpAndSettle();

      expect(services.screenBrightness, isNotNull);
      expect(services.keepScreenOn, isTrue);

      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.theme!.brightness, Brightness.light);
    });

    testWidgets('la pantalla no se apaga sola desde el arranque', (
      tester,
    ) async {
      await pumpApp(tester);
      await tester.pumpAndSettle();

      expect(services.keepScreenOn, isTrue);
    });

    testWidgets('los chips de la barra encienden y apagan sus controles', (
      tester,
    ) async {
      await pumpApp(tester);
      orientation.emit(tilt: 5);
      await tester.pumpAndSettle();

      final rest = padRect(tester);

      await tester.tap(find.byKey(const ValueKey('torchChip')));
      await tester.pumpAndSettle();
      expect(services.torchOn, isTrue);
      // El mando se coloca solo: la marca sube al tope de la linterna.
      expect(
        tester.widget<ControlPad>(find.byType(ControlPad)).torchIntensity,
        closeTo(1, 0.001),
      );

      await tester.tap(find.byKey(const ValueKey('beaconChip')));
      await tester.pumpAndSettle();
      // Los dos chips conmutan igual: apagado o al 100 %.
      expect(services.screenBrightness, closeTo(1, 0.001));
      expect(
        tester.widget<ControlPad>(find.byType(ControlPad)).beaconLevel,
        closeTo(1, 0.001),
      );

      // El mando sigue en su sitio: los chips no lo mueven de la pantalla.
      expect(padRect(tester), rest);

      await tester.tap(find.byKey(const ValueKey('torchChip')));
      await tester.tap(find.byKey(const ValueKey('beaconChip')));
      await tester.pumpAndSettle();

      expect(services.torchOn, isFalse);
      expect(services.screenBrightness, isNull);
    });

    testWidgets('la linterna no cambia el tema', (tester) async {
      await pumpApp(tester);
      orientation.emit(tilt: 5);
      await tester.pumpAndSettle();

      final pad = padRect(tester);
      await tester.tapAt(Offset(pad.right - 24, pad.top + 24));
      await tester.pumpAndSettle();

      expect(services.torchOn, isTrue);
      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.theme!.brightness, Brightness.dark);
    });
  });
}
