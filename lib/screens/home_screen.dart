import 'package:flutter/material.dart';

import '../controllers/controls_controller.dart';
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
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(error)));
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

/// Fila superior: qué vista está activa y el estado de los dos controles.
class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.controller, required this.pose});

  final ControlsController controller;
  final DevicePose pose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          return Row(
            children: [
              Icon(
                pose == DevicePose.flat
                    ? Icons.explore_rounded
                    : Icons.straighten_rounded,
                size: 18,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  pose == DevicePose.flat
                      ? 'En horizontal · brújula'
                      : 'En vertical · regla de rumbos',
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ),
              _StateChip(
                icon: Icons.flashlight_on_rounded,
                on: controller.torchOn,
                color: theme.colorScheme.primary,
                label: 'Linterna',
                level: controller.torchIsGradual
                    ? controller.torchIntensity
                    : null,
              ),
              const SizedBox(width: 8),
              _StateChip(
                icon: Icons.wb_sunny_rounded,
                on: controller.beaconOn,
                color: theme.colorScheme.secondary,
                label: 'Faro',
                level: controller.beaconLevel,
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
    required this.label,
    this.level,
  });

  final IconData icon;
  final bool on;
  final Color color;
  final String label;

  /// Nivel de 0 a 1, o `null` si este control no se puede graduar.
  final double? level;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final percentage = level == null ? null : (level! * 100).round();
    final state = on
        ? (percentage == null ? 'encendida' : 'al $percentage por ciento')
        : 'apagada';

    return Semantics(
      label: '$label $state',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: on ? color : scheme.onSurface.withValues(alpha: 0.08),
            ),
            child: Icon(
              icon,
              size: 16,
              color: on
                  ? Colors.black87
                  : scheme.onSurface.withValues(alpha: 0.45),
            ),
          ),
          if (on && percentage != null) ...[
            const SizedBox(width: 4),
            Text(
              '$percentage%',
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
