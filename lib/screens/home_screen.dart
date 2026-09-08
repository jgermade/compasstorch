import 'package:flutter/material.dart';

import '../controllers/controls_controller.dart';
import '../l10n/app_strings.dart';
import '../services/orientation_service.dart';
import '../widgets/compass_dial.dart';
import '../widgets/control_pad.dart';
import '../widgets/heading_ribbon.dart';

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
  });

  final ControlsController controller;
  final OrientationService orientation;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DevicePose _pose = DevicePose.flat;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    // Saber si el flash se puede graduar cambia cómo se comporta el eje
    // vertical del mando, así que se pregunta cuanto antes.
    widget.controller.loadTorchCapabilities();
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

            return Column(
              children: [
                _StatusBar(controller: widget.controller, pose: _pose),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 320),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      child: _pose == DevicePose.flat
                          ? CompassDial(
                              key: const ValueKey('dial'),
                              heading: reading?.headingTop,
                              levelX: reading?.levelX ?? 0,
                              levelY: reading?.levelY ?? 0,
                              onLevelled: widget.controller.pulseLevelled,
                            )
                          : HeadingRibbon(
                              key: const ValueKey('ribbon'),
                              heading: reading?.headingCamera,
                              elevation: reading?.elevation ?? 0,
                            ),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: AnimatedBuilder(
                      animation: widget.controller,
                      builder: (context, child) => ControlPad(
                        torchOn: widget.controller.torchOn,
                        beaconOn: widget.controller.beaconOn,
                        torchIntensity: widget.controller.torchIntensity,
                        beaconLevel: widget.controller.beaconLevel,
                        torchIsGradual: widget.controller.torchIsGradual,
                        onTorchChanged: (enabled, level) => widget.controller
                            .setTorch(enabled: enabled, intensity: level),
                        onBeaconChanged: (enabled, level) => widget.controller
                            .setBeacon(enabled: enabled, level: level),
                        onZoneChanged: widget.controller.pulseZoneChange,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Fila superior: el modo faro en una esquina, la linterna en la otra y, en
/// medio, el icono de la vista que está activa.
class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.controller, required this.pose});

  final ControlsController controller;
  final DevicePose pose;

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
                    icon: Icons.wb_sunny_rounded,
                    on: controller.beaconOn,
                    color: theme.colorScheme.secondary,
                    semanticsLabel: strings.beaconState(
                      on: controller.beaconOn,
                      percent: (controller.beaconLevel * 100).round(),
                    ),
                    level: controller.beaconLevel,
                  ),
                ),
              ),
              Semantics(
                label: flat ? strings.compassView : strings.bearingRulerView,
                child: Icon(
                  flat ? Icons.explore_rounded : Icons.straighten_rounded,
                  size: 18,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                ),
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _StateChip(
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

class _StateChip extends StatelessWidget {
  const _StateChip({
    required this.icon,
    required this.on,
    required this.color,
    required this.semanticsLabel,
    this.level,
    this.textFirst = false,
  });

  final IconData icon;
  final bool on;
  final Color color;

  /// Cómo lo cuenta un lector de pantalla; en la pantalla solo se ve el icono
  /// y, si el control se gradúa, el porcentaje.
  final String semanticsLabel;

  /// Nivel de 0 a 1, o `null` si este control no se puede graduar.
  final double? level;

  /// El porcentaje va a la izquierda del icono, para el chip de la derecha.
  final bool textFirst;

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
        color: on ? color : scheme.onSurface.withValues(alpha: 0.08),
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (textFirst && text != null) ...[text, const SizedBox(width: 4)],
          badge,
          if (!textFirst && text != null) ...[const SizedBox(width: 4), text],
        ],
      ),
    );
  }
}
