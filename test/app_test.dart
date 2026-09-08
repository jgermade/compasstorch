import 'dart:async';

import 'package:compasstorch/main.dart';
import 'package:compasstorch/screens/home_screen.dart';
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

  void emit({required double tilt, double heading = 0}) {
    _controller.add(
      OrientationReading(
        headingTop: heading,
        headingCamera: heading,
        elevation: 0,
        tilt: tilt,
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

      expect(services.maxBrightness, isTrue);
      expect(services.keepScreenOn, isTrue);

      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.theme!.brightness, Brightness.light);
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
