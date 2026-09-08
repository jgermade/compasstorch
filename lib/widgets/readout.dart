import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';

/// Lectura numérica grande del rumbo, compartida por las dos vistas: los
/// grados y, debajo, el rumbo al que corresponden.
class HeadingReadout extends StatelessWidget {
  const HeadingReadout({super.key, required this.heading});

  final double heading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppStrings.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${heading.round() % 360}°',
          style: theme.textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w300,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        Text(
          strings.cardinalFor(heading),
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            letterSpacing: 1.4,
          ),
        ),
      ],
    );
  }
}

/// Mensaje mientras no hay lecturas fiables del magnetómetro.
class SensorPlaceholder extends StatelessWidget {
  const SensorPlaceholder({super.key, this.upright = false});

  /// La pista cambia con la postura: tumbado basta con mover el teléfono;
  /// levantado hay que decir además que se levante.
  final bool upright;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppStrings.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.explore_outlined,
              size: 44,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              strings.calibrating,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              upright
                  ? strings.calibrateHintUpright
                  : strings.calibrateHintFlat,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
