import 'package:flutter/material.dart';

import 'cardinals.dart';

/// Lectura numérica grande del rumbo, compartida por las dos vistas.
class HeadingReadout extends StatelessWidget {
  const HeadingReadout({super.key, required this.heading, required this.label});

  final double heading;

  /// Texto corto que explica qué mide el rumbo ("rumbo", "apuntando a"…).
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
          '${cardinalFor(heading)} · $label',
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
  const SensorPlaceholder({
    super.key,
    this.message = 'Buscando el campo magnético…',
    this.hint = 'Mueve el teléfono dibujando un ocho para calibrar la brújula.',
  });

  final String message;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              hint,
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
