import 'package:compasstorch/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test.dart' show FakeOrientationService;
import 'fake_device_services.dart';
import 'fake_selfie_camera.dart';

void main() {
  late FakeDeviceServices services;
  late FakeOrientationService orientation;
  late FakeSelfieCamera camera;

  setUp(() {
    services = FakeDeviceServices();
    orientation = FakeOrientationService();
    camera = FakeSelfieCamera();
  });

  tearDown(() {
    orientation.close();
    TestWidgetsFlutterBinding.instance.platformDispatcher
        .clearLocalesTestValue();
  });

  Future<void> pumpApp(WidgetTester tester, Locale locale) async {
    tester.platformDispatcher.localesTestValue = [locale];
    await tester.pumpWidget(
      CompassTorchApp(
        services: services,
        orientation: orientation,
        camera: camera,
      ),
    );
    await tester.pump();
  }

  testWidgets('en castellano los textos y los rumbos van en castellano', (
    tester,
  ) async {
    await pumpApp(tester, const Locale('es'));

    // Sin lecturas todavía: se ve el aviso de calibración.
    expect(find.textContaining('Buscando el campo magnético'), findsOneWidget);

    orientation.emit(tilt: 5, heading: 270);
    await tester.pumpAndSettle();
    expect(find.text('O'), findsOneWidget);
  });

  testWidgets('en inglés los rumbos usan las abreviaturas inglesas', (
    tester,
  ) async {
    await pumpApp(tester, const Locale('en'));

    expect(
      find.textContaining('Looking for the magnetic field'),
      findsOneWidget,
    );

    orientation.emit(tilt: 5, heading: 270);
    await tester.pumpAndSettle();
    expect(find.text('W'), findsOneWidget);
  });

  testWidgets('un idioma sin traducir cae en el inglés', (tester) async {
    await pumpApp(tester, const Locale('fr'));

    expect(
      find.textContaining('Looking for the magnetic field'),
      findsOneWidget,
    );

    orientation.emit(tilt: 5, heading: 270);
    await tester.pumpAndSettle();
    expect(find.text('W'), findsOneWidget);
  });
}
