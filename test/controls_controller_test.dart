import 'package:compasstorch/controllers/controls_controller.dart';
import 'package:compasstorch/services/haptics.dart';
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

  test('encender la linterna comprueba antes las capacidades', () async {
    await controller.setTorch(enabled: true);

    expect(controller.torchOn, isTrue);
    expect(services.torchOn, isTrue);
    expect(services.calls, [
      'torchCapabilities',
      'setTorch(true, 1.00)',
      'haptic(turnedOn)',
    ]);
  });

  test('sin flash disponible el estado vuelve atrás y avisa', () async {
    services.torchAvailable = false;

    await controller.setTorch(enabled: true);

    expect(controller.torchOn, isFalse);
    expect(services.torchOn, isFalse);
    expect(controller.takeError(), ControlsError.torchUnavailable);
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
      expect(services.screenBrightness, isNotNull);
      expect(services.keepScreenOn, isTrue);
    },
  );

  test('apagar el modo faro devuelve el brillo de la pantalla', () async {
    await controller.setBeacon(enabled: true);
    await controller.setBeacon(enabled: false);

    expect(controller.beaconOn, isFalse);
    expect(services.screenBrightness, isNull);
    // La pantalla sigue sin apagarse sola: eso lo manda la inhibición general,
    // que viene puesta y no depende del faro.
    expect(services.keepScreenOn, isTrue);
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
    services.screenBrightness = null; // el sistema lo ha restaurado

    await controller.reapplyScreenSettings();

    expect(services.screenBrightness, isNotNull);
  });

  test(
    'sin modo faro no se toca el brillo al volver del segundo plano',
    () async {
      await controller.reapplyScreenSettings();

      // Solo se vuelve a pedir el bloqueo, que el sistema suelta al ocultarse
      // la aplicación.
      expect(services.calls, ['setKeepScreenOn(true)']);
      expect(services.screenBrightness, isNull);
    },
  );

  group('bloqueo del apagado de pantalla', () {
    test('viene activado y se aplica al arrancar', () async {
      expect(controller.keepAwake, isTrue);

      await controller.applyKeepAwake();

      expect(services.keepScreenOn, isTrue);
    });

    test('se puede desactivar y volver a activar', () async {
      await controller.applyKeepAwake();

      await controller.toggleKeepAwake();
      expect(controller.keepAwake, isFalse);
      expect(services.keepScreenOn, isFalse);

      await controller.toggleKeepAwake();
      expect(controller.keepAwake, isTrue);
      expect(services.keepScreenOn, isTrue);
    });

    test('el cambio se confirma con una vibración', () async {
      await controller.toggleKeepAwake();
      await controller.toggleKeepAwake();

      expect(services.haptics, [HapticCue.turnedOff, HapticCue.turnedOn]);
    });

    test('el modo faro mantiene la pantalla aunque esté desactivado', () async {
      await controller.toggleKeepAwake();
      expect(services.keepScreenOn, isFalse);

      await controller.setBeacon(enabled: true);
      expect(services.keepScreenOn, isTrue);

      // Y al apagar el faro se vuelve a respetar lo que se eligió.
      await controller.setBeacon(enabled: false);
      expect(services.keepScreenOn, isFalse);
    });
  });

  group('conmutar desde la barra de estado', () {
    test('la linterna se enciende al máximo y se apaga', () async {
      await controller.toggleTorch();

      expect(controller.torchOn, isTrue);
      expect(services.torchIntensity, closeTo(1, 0.001));

      await controller.toggleTorch();

      expect(controller.torchOn, isFalse);
      expect(services.torchOn, isFalse);
    });

    test('la linterna recupera el nivel que tenía', () async {
      await controller.setTorch(enabled: true, intensity: 0.4);
      await controller.toggleTorch();
      await controller.toggleTorch();

      expect(controller.torchOn, isTrue);
      expect(controller.torchIntensity, closeTo(0.4, 0.001));
    });

    test('el faro se activa al máximo y se desactiva', () async {
      await controller.toggleBeacon();

      expect(controller.beaconOn, isTrue);
      expect(controller.beaconLevel, closeTo(1, 0.001));
      expect(services.screenBrightness, closeTo(1, 0.001));

      await controller.toggleBeacon();

      expect(controller.beaconOn, isFalse);
      expect(services.screenBrightness, isNull);
    });

    test('el faro recupera el brillo que tenía', () async {
      await controller.setBeacon(enabled: true, level: 0.5);
      final chosen = services.screenBrightness!;
      await controller.toggleBeacon();
      await controller.toggleBeacon();

      expect(controller.beaconOn, isTrue);
      expect(services.screenBrightness, closeTo(chosen, 0.001));
    });
  });

  group('vibración háptica', () {
    test(
      'el tic de cambio de banda es más suave que el de encendido',
      () async {
        await controller.setTorch(enabled: true);
        await controller.pulseZoneChange();

        expect(services.haptics, [HapticCue.turnedOn, HapticCue.zoneChanged]);
      },
    );

    test('la linterna vibra al encender y al apagar', () async {
      await controller.setTorch(enabled: true);
      expect(services.haptics, [HapticCue.turnedOn]);

      await controller.setTorch(enabled: false);
      expect(services.haptics, [HapticCue.turnedOn, HapticCue.turnedOff]);
    });

    test('el modo faro vibra al activar y al desactivar', () async {
      await controller.setBeacon(enabled: true);
      await controller.setBeacon(enabled: false);

      expect(services.haptics, [HapticCue.turnedOn, HapticCue.turnedOff]);
    });

    test('sin flash no vibra: no ha llegado a encenderse', () async {
      services.torchAvailable = false;

      await controller.setTorch(enabled: true);

      expect(services.haptics, isEmpty);
    });

    test('repetir el mismo estado no vibra otra vez', () async {
      await controller.setTorch(enabled: true);
      await controller.setTorch(enabled: true);

      expect(services.haptics, [HapticCue.turnedOn]);
    });

    test('el modo faro vibra aunque el brillo no se deje ajustar', () async {
      services.failOnBrightness = true;

      await controller.setBeacon(enabled: true);

      expect(controller.beaconOn, isTrue);
      expect(services.haptics, [HapticCue.turnedOn]);
    });
  });

  group('intensidad regulable', () {
    test('la intensidad pedida llega al dispositivo al encender', () async {
      await controller.setTorch(enabled: true, intensity: 0.4);

      expect(controller.torchIntensity, closeTo(0.4, 0.001));
      expect(services.torchIntensity, closeTo(0.4, 0.001));
    });

    test(
      'cambiar el nivel con la linterna encendida no vuelve a vibrar',
      () async {
        await controller.setTorch(enabled: true, intensity: 1);
        services.haptics.clear();

        await controller.setTorchIntensity(0.5);
        await controller.setTorchIntensity(0.25);

        expect(services.haptics, isEmpty);
        expect(services.torchIntensity, closeTo(0.25, 0.001));
      },
    );

    test(
      'sin soporte de gradación no se manda el nivel al dispositivo',
      () async {
        services.torchGradual = false;
        await controller.setTorch(enabled: true);
        services.torchLevels.clear();

        await controller.setTorchIntensity(0.3);

        expect(controller.torchIsGradual, isFalse);
        // El valor se recuerda para la interfaz, pero no viaja al flash.
        expect(controller.torchIntensity, closeTo(0.3, 0.001));
        expect(services.torchLevels, isEmpty);
      },
    );

    test('con la linterna apagada el nivel no llega al dispositivo', () async {
      await controller.setTorchIntensity(0.7);

      expect(controller.torchIntensity, closeTo(0.7, 0.001));
      expect(services.torchLevels, isEmpty);
    });

    test(
      'una ráfaga de niveles converge al último sin encolarlos todos',
      () async {
        await controller.setTorch(enabled: true, intensity: 1);
        services.torchLevels.clear();

        // Como al arrastrar: muchos valores seguidos sin esperar a cada envío.
        final burst = [
          controller.setTorchIntensity(0.9),
          controller.setTorchIntensity(0.8),
          controller.setTorchIntensity(0.7),
          controller.setTorchIntensity(0.6),
          controller.setTorchIntensity(0.5),
        ];
        await Future.wait(burst);

        expect(services.torchIntensity, closeTo(0.5, 0.001));
        // Se manda el primero y luego solo el último pendiente, no los cinco.
        expect(services.torchLevels.length, lessThan(burst.length));
        expect(services.torchLevels.last, closeTo(0.5, 0.001));
      },
    );
  });

  group('brillo regulable del modo faro', () {
    test('el nivel del mando se traduce a brillo con un suelo', () async {
      await controller.setBeacon(enabled: true, level: 1);
      expect(services.screenBrightness, closeTo(1, 0.001));

      await controller.setBeaconLevel(0);
      // Nunca baja de ControlsController.minBeaconBrightness: con la pantalla
      // negra no se vería el mando para volver a subirla.
      expect(
        services.screenBrightness,
        closeTo(ControlsController.minBeaconBrightness, 0.001),
      );
    });

    test(
      'a mitad de recorrido el brillo queda entre el suelo y el máximo',
      () async {
        await controller.setBeacon(enabled: true, level: 0.5);

        final brightness = services.screenBrightness!;
        expect(brightness, greaterThan(ControlsController.minBeaconBrightness));
        expect(brightness, lessThan(1));
      },
    );

    test('cambiar el brillo no repite la vibración', () async {
      await controller.setBeacon(enabled: true, level: 1);
      services.haptics.clear();

      await controller.setBeaconLevel(0.4);

      expect(services.haptics, isEmpty);
    });

    test(
      'al volver del segundo plano se restaura el nivel elegido, no el máximo',
      () async {
        await controller.setBeacon(enabled: true, level: 0.5);
        final chosen = services.screenBrightness!;
        services.screenBrightness = null;

        await controller.reapplyScreenSettings();

        expect(services.screenBrightness, closeTo(chosen, 0.001));
      },
    );
  });

  test('al salir se apaga el flash y se restauran los ajustes', () async {
    await controller.setTorch(enabled: true);
    await controller.setBeacon(enabled: true);

    await controller.restoreDefaults();

    expect(services.torchOn, isFalse);
    expect(services.screenBrightness, isNull);
    expect(services.keepScreenOn, isFalse);
  });
}
