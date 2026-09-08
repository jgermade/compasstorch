import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'controllers/controls_controller.dart';
import 'screens/home_screen.dart';
import 'services/device_services.dart';
import 'services/orientation_service.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // La pantalla se reparte en dos mitades pensadas para vertical; qué vista de
  // brújula se muestra lo decide la inclinación del teléfono, no el giro de la
  // pantalla, así que no hace falta rotar la interfaz.
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(
    CompassTorchApp(
      services: const PlatformDeviceServices(),
      orientation: SensorOrientationService(),
    ),
  );
}

/// Brújula con un mando deslizable para la linterna y el modo faro.
class CompassTorchApp extends StatefulWidget {
  const CompassTorchApp({
    super.key,
    required this.services,
    required this.orientation,
  });

  final DeviceServices services;
  final OrientationService orientation;

  @override
  State<CompassTorchApp> createState() => _CompassTorchAppState();
}

class _CompassTorchAppState extends State<CompassTorchApp> {
  late final ControlsController _controller =
      ControlsController(widget.services);
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      // Al volver del segundo plano el sistema ha devuelto el brillo a su
      // valor normal, así que el modo faro debe reaplicarse.
      onResume: _controller.reapplyScreenSettings,
      onDetach: () {
        // En móvil la aplicación puede terminar sin pedir permiso: se apaga
        // el flash igualmente para no dejarlo encendido.
        _controller.restoreDefaults();
      },
      onExitRequested: () async {
        await _controller.restoreDefaults();
        return AppExitResponse.exit;
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final beacon = _controller.beaconOn;
        return MaterialApp(
          title: 'Brújula y linterna',
          debugShowCheckedModeBanner: false,
          // El tema lo manda la aplicación, no el ajuste del sistema: oscuro
          // siempre, salvo con el modo faro activo.
          themeMode: ThemeMode.light,
          theme: beacon ? buildBeaconTheme() : buildDarkTheme(),
          builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
            value: beacon
                ? SystemUiOverlayStyle.dark
                : SystemUiOverlayStyle.light,
            child: child!,
          ),
          home: HomeScreen(
            controller: _controller,
            orientation: widget.orientation,
          ),
        );
      },
    );
  }
}
