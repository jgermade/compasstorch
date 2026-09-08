import 'package:compasstorch/controllers/controls_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_device_services.dart';

void main() {
  late FakeDeviceServices services;
  late ControlsController controller;

  setUp(() {
    services = FakeDeviceServices();
    controller = ControlsController(services);
  });

  test('empieza con la linterna y el modo faro apagados', () {
    expect(controller.torchOn, isFalse);
    expect(controller.beaconOn, isFalse);
  });

  test('encender la linterna comprueba antes que hay flash', () async {
    await controller.setTorch(enabled: true);

    expect(controller.torchOn, isTrue);
    expect(services.torchOn, isTrue);
    expect(services.calls, [
      'isTorchAvailable',
      'setTorch(true)',
      'hapticPulse(true)',
    ]);
  });

  test('sin flash disponible el estado vuelve atrás y avisa', () async {
    services.torchAvailable = false;

    await controller.setTorch(enabled: true);

    expect(controller.torchOn, isFalse);
    expect(services.torchOn, isFalse);
    expect(controller.takeError(), contains('linterna'));
    // El aviso se consume una sola vez.
    expect(controller.takeError(), isNull);
  });

  test('un fallo del plugin al encender revierte el estado', () async {
    services.failOnTorch = true;

    await controller.setTorch(enabled: true);

    expect(controller.torchOn, isFalse);
    expect(controller.takeError(), isNotNull);
  });

  test(
    'el modo faro sube el brillo y bloquea el apagado de pantalla',
    () async {
      await controller.setBeacon(enabled: true);

      expect(controller.beaconOn, isTrue);
      expect(services.maxBrightness, isTrue);
      expect(services.keepScreenOn, isTrue);
    },
  );

  test('apagar el modo faro devuelve el brillo y libera la pantalla', () async {
    await controller.setBeacon(enabled: true);
    await controller.setBeacon(enabled: false);

    expect(controller.beaconOn, isFalse);
    expect(services.maxBrightness, isFalse);
    expect(services.keepScreenOn, isFalse);
  });

  test('los dos controles son independientes', () async {
    await controller.setTorch(enabled: true);
    await controller.setBeacon(enabled: true);

    expect(controller.torchOn, isTrue);
    expect(controller.beaconOn, isTrue);

    await controller.setTorch(enabled: false);

    expect(controller.torchOn, isFalse);
    expect(controller.beaconOn, isTrue);
  });

  test('al volver del segundo plano se reaplica el brillo máximo', () async {
    await controller.setBeacon(enabled: true);
    services.maxBrightness = false; // el sistema lo ha restaurado

    await controller.reapplyScreenSettings();

    expect(services.maxBrightness, isTrue);
  });

  test(
    'sin modo faro no se toca el brillo al volver del segundo plano',
    () async {
      await controller.reapplyScreenSettings();

      expect(services.calls, isEmpty);
    },
  );

  group('vibración háptica', () {
    test('la linterna vibra al encender y al apagar', () async {
      await controller.setTorch(enabled: true);
      expect(services.haptics, [true]);

      await controller.setTorch(enabled: false);
      expect(services.haptics, [true, false]);
    });

    test('el modo faro vibra al activar y al desactivar', () async {
      await controller.setBeacon(enabled: true);
      await controller.setBeacon(enabled: false);

      expect(services.haptics, [true, false]);
    });

    test('sin flash no vibra: no ha llegado a encenderse', () async {
      services.torchAvailable = false;

      await controller.setTorch(enabled: true);

      expect(services.haptics, isEmpty);
    });

    test('repetir el mismo estado no vibra otra vez', () async {
      await controller.setTorch(enabled: true);
      await controller.setTorch(enabled: true);

      expect(services.haptics, [true]);
    });

    test('el modo faro vibra aunque el brillo no se deje ajustar', () async {
      services.failOnBrightness = true;

      await controller.setBeacon(enabled: true);

      expect(controller.beaconOn, isTrue);
      expect(services.haptics, [true]);
    });
  });

  test('al salir se apaga el flash y se restauran los ajustes', () async {
    await controller.setTorch(enabled: true);
    await controller.setBeacon(enabled: true);

    await controller.restoreDefaults();

    expect(services.torchOn, isFalse);
    expect(services.maxBrightness, isFalse);
    expect(services.keepScreenOn, isFalse);
  });
}
