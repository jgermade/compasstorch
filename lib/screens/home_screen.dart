import 'package:flutter/material.dart';

import '../controllers/controls_controller.dart';
import '../l10n/app_strings.dart';
import '../services/orientation_service.dart';
import '../services/selfie_camera.dart';
import '../theme.dart';
import '../widgets/compass_dial.dart';
import '../widgets/control_pad.dart';
import '../widgets/heading_ribbon.dart';
import '../widgets/selfie_view.dart';

/// Decide qué vista mostrar según la inclinación del teléfono.
///
/// Entre los dos umbrales se conserva la vista actual, para que no cambie sola
/// cuando la inclinación se queda justo en el límite.
DevicePose poseFor(double tilt, DevicePose current) {
  const flatBelow = 35.0;
  const uprightAbove = 55.0;
  if (tilt < flatBelow) return DevicePose.flat;
  if (tilt > uprightAbove) return DevicePose.upright;
  return current;
}

/// Pantalla única: brújula en la mitad de arriba, mando en la mitad de abajo.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.controller,
    required this.orientation,
    required this.camera,
  });

  final ControlsController controller;
  final OrientationService orientation;

  /// Cámara frontal de la vista de espejo, que se alterna con la regla de
  /// rumbos cuando el teléfono está levantado.
  final SelfieCamera camera;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

/// Relleno de cada una de las dos mitades. Es el mismo para las dos para que
/// los dos huecos midan igual: el mando y el espejo son cuadrados del lado
/// corto de su hueco, así que solo salen del mismo ancho si el hueco es el
/// mismo.
const _viewInsets = EdgeInsets.symmetric(horizontal: 16, vertical: 8);

class _HomeScreenState extends State<HomeScreen> {
  DevicePose _pose = DevicePose.flat;

  /// En vertical se está viendo la cámara frontal en vez de la regla de
  /// rumbos. Con el teléfono tumbado no pinta nada, así que se vuelve sola a
  /// la regla al bajar el teléfono.
  bool _selfie = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    // Saber si el flash se puede graduar cambia cómo se comporta el eje
    // vertical del mando, así que se pregunta cuanto antes.
    widget.controller.loadTorchCapabilities();
    // La aplicación se usa mirando a otro sitio: la pantalla no se apaga sola
    // mientras esté abierta, salvo que se desactive desde el mando.
    widget.controller.applyKeepAwake();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    final error = widget.controller.takeError();
    if (error == null || !mounted) return;
    final strings = AppStrings.of(context);
    final message = switch (error) {
      ControlsError.torchUnavailable => strings.torchUnavailable,
      ControlsError.torchOffFailed => strings.torchOffFailed,
      ControlsError.beaconPartial => strings.beaconPartial,
    };
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<OrientationReading>(
          stream: widget.orientation.readings,
          builder: (context, snapshot) {
            final reading = snapshot.data;
            if (reading != null) {
              _pose = poseFor(reading.tilt, _pose);
            }
            // La cámara es cosa del modo vertical: al tumbar el teléfono se
            // vuelve a la regla, y con ella la cámara se suelta.
            if (_pose == DevicePose.flat) _selfie = false;

            // El margen de abajo va fuera de la columna a propósito: así los
            // dos huecos de dentro llevan exactamente el mismo relleno y
            // miden lo mismo, que es lo que hace que el espejo y el mando
            // salgan del mismo ancho.
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                children: [
                  _StatusBar(
                    controller: widget.controller,
                    pose: _pose,
                    selfie: _selfie,
                    onToggleView: () => setState(() => _selfie = !_selfie),
                  ),
                  Expanded(
                    child: Padding(
                      padding: _viewInsets,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 320),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        child: switch ((_pose, _selfie)) {
                          (DevicePose.flat, _) => CompassDial(
                            key: const ValueKey('dial'),
                            heading: reading?.headingTop,
                            levelX: reading?.levelX ?? 0,
                            levelY: reading?.levelY ?? 0,
                            onLevelled: widget.controller.pulseLevelled,
                          ),
                          (DevicePose.upright, false) => HeadingRibbon(
                            key: const ValueKey('ribbon'),
                            heading: reading?.headingCamera,
                            elevation: reading?.elevation ?? 0,
                          ),
                          (DevicePose.upright, true) => SelfieView(
                            key: const ValueKey('selfie'),
                            camera: widget.camera,
                          ),
                        },
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: _viewInsets,
                      child: AnimatedBuilder(
                        animation: widget.controller,
                        builder: (context, child) => ControlPad(
                          torchOn: widget.controller.torchOn,
                          beaconOn: widget.controller.beaconOn,
                          torchIntensity: widget.controller.torchIntensity,
                          beaconLevel: widget.controller.beaconLevel,
                          torchIsGradual: widget.controller.torchIsGradual,
                          keepAwake: widget.controller.keepAwake,
                          onTorchChanged: (enabled, level) => widget.controller
                              .setTorch(enabled: enabled, intensity: level),
                          onBeaconChanged: (enabled, level) => widget.controller
                              .setBeacon(enabled: enabled, level: level),
                          onZoneChanged: widget.controller.pulseZoneChange,
                          onToggleKeepAwake: widget.controller.toggleKeepAwake,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Fila superior: el modo faro en una esquina, la linterna en la otra y, en
/// medio, la vista que está activa.
///
/// Los dos chips no solo informan: tocarlos enciende o apaga su control, y el
/// mando de abajo se coloca solo donde corresponda. En medio, con el teléfono
/// tumbado solo se ve el icono de la brújula, porque no hay nada que elegir;
/// levantado se convierte en un botón que alterna la regla y la cámara.
class _StatusBar extends StatelessWidget {
  const _StatusBar({
    required this.controller,
    required this.pose,
    required this.selfie,
    required this.onToggleView,
  });

  final ControlsController controller;
  final DevicePose pose;

  /// En vertical se está viendo la cámara frontal en vez de la regla.
  final bool selfie;

  /// Cambia entre las dos vistas del modo vertical.
  final VoidCallback onToggleView;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppStrings.of(context);
    final flat = pose == DevicePose.flat;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          return Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _StateChip(
                    key: const ValueKey('beaconChip'),
                    // El mismo icono que lleva el faro en el mando, para que
                    // se lean como el mismo control.
                    icon: Icons.brightness_high,
                    on: controller.beaconOn,
                    color: theme.colorScheme.secondary,
                    badgeColor: AppColors.beaconLight,
                    semanticsLabel: strings.beaconState(
                      on: controller.beaconOn,
                      percent: (controller.beaconLevel * 100).round(),
                    ),
                    level: controller.beaconLevel,
                    onTap: controller.toggleBeacon,
                  ),
                ),
              ),
              if (flat)
                Semantics(
                  label: strings.compassView,
                  child: Icon(
                    Icons.explore_rounded,
                    size: 18,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                )
              else
                _ViewToggle(selfie: selfie, onTap: onToggleView),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _StateChip(
                    key: const ValueKey('torchChip'),
                    icon: Icons.flashlight_on_rounded,
                    on: controller.torchOn,
                    color: theme.colorScheme.primary,
                    semanticsLabel: strings.torchState(
                      on: controller.torchOn,
                      percent: controller.torchIsGradual
                          ? (controller.torchIntensity * 100).round()
                          : null,
                    ),
                    level: controller.torchIsGradual
                        ? controller.torchIntensity
                        : null,
                    textFirst: true,
                    onTap: controller.toggleTorch,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Botón de las dos vistas del modo vertical: la regla de rumbos y la cámara
/// frontal. Los dos iconos se ven siempre, y el de la vista activa es el que
/// va encendido, para que se lea de un vistazo qué se está viendo y qué hay
/// al otro lado.
class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.selfie, required this.onTap});

  final bool selfie;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      label: strings.viewToggle(selfie: selfie),
      button: true,
      child: InkWell(
        key: const ValueKey('viewToggle'),
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Container(
          // Holgado a propósito: los dos iconos son pequeños y el botón
          // necesita un área de toque cómoda.
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: ShapeDecoration(
            shape: StadiumBorder(
              side: BorderSide(color: scheme.onSurface.withValues(alpha: 0.18)),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ViewToggleIcon(icon: Icons.straighten_rounded, active: !selfie),
              const SizedBox(width: 8),
              _ViewToggleIcon(
                icon: Icons.photo_camera_front_rounded,
                active: selfie,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ViewToggleIcon extends StatelessWidget {
  const _ViewToggleIcon({required this.icon, required this.active});

  final IconData icon;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 220),
      // El icono apagado no desaparece: se queda tenue para anunciar la otra
      // vista, que es a donde lleva el botón.
      opacity: active ? 0.9 : 0.3,
      child: Icon(icon, size: 18, color: scheme.onSurface),
    );
  }
}

class _StateChip extends StatelessWidget {
  const _StateChip({
    super.key,
    required this.icon,
    required this.on,
    required this.color,
    required this.semanticsLabel,
    required this.onTap,
    this.badgeColor,
    this.level,
    this.textFirst = false,
  });

  final IconData icon;
  final bool on;

  /// Color del porcentaje, que va sobre el fondo de la pantalla.
  final Color color;

  /// Color del disco del icono, cuando no es el mismo que el del texto. El
  /// porcentaje necesita contrastar con el fondo y el disco no.
  final Color? badgeColor;

  /// Cómo lo cuenta un lector de pantalla; en la pantalla solo se ve el icono
  /// y, si el control se gradúa, el porcentaje.
  final String semanticsLabel;

  /// Nivel de 0 a 1, o `null` si este control no se puede graduar.
  final double? level;

  /// El porcentaje va a la izquierda del icono, para el chip de la derecha.
  final bool textFirst;

  /// Enciende o apaga el control al tocar el chip.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final percentage = level == null ? null : (level! * 100).round();

    final badge = AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: on
            ? (badgeColor ?? color)
            : scheme.onSurface.withValues(alpha: 0.08),
      ),
      child: Icon(
        icon,
        size: 16,
        color: on ? Colors.black87 : scheme.onSurface.withValues(alpha: 0.45),
      ),
    );

    final text = on && percentage != null
        ? Text(
            '$percentage%',
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          )
        : null;

    return Semantics(
      label: semanticsLabel,
      button: true,
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          // El disco es pequeño: el relleno le da un área de toque cómoda sin
          // separar los chips de las esquinas.
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (textFirst && text != null) ...[
                text,
                const SizedBox(width: 4),
              ],
              badge,
              if (!textFirst && text != null) ...[
                const SizedBox(width: 4),
                text,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
