import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'cardinals.dart';
import 'readout.dart';

/// Regla de rumbos: una cinta de líneas verticales que se desplaza según hacia
/// dónde apunta la parte trasera del teléfono. Es la vista que se usa con el
/// teléfono levantado, cuando se apunta a algo del paisaje.
class HeadingRibbon extends StatelessWidget {
  const HeadingRibbon({
    super.key,
    required this.heading,
    required this.elevation,
  });

  /// Rumbo magnético al que apunta el teléfono, o `null` sin lectura.
  final double? heading;

  /// Elevación sobre el horizonte, en grados.
  final double elevation;

  /// Amplitud de la cinta, en grados de lado a lado.
  static const double fieldOfView = 90;

  /// Alto máximo de la cinta: por encima solo añadiría hueco vacío.
  static const double maxRibbonHeight = 200;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = heading;

    if (value == null) {
      return const SensorPlaceholder(
        hint: 'Levanta el teléfono y muévelo dibujando un ocho para calibrar.',
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          HeadingReadout(heading: value, label: 'apuntando a'),
          const SizedBox(height: 18),
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: maxRibbonHeight),
              child: SizedBox(
                width: double.infinity,
                child: _AnimatedRibbon(heading: value, theme: theme),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _ElevationBar(elevation: elevation),
        ],
      ),
    );
  }
}

class _AnimatedRibbon extends StatefulWidget {
  const _AnimatedRibbon({required this.heading, required this.theme});

  final double heading;
  final ThemeData theme;

  @override
  State<_AnimatedRibbon> createState() => _AnimatedRibbonState();
}

class _AnimatedRibbonState extends State<_AnimatedRibbon> {
  /// Rumbo acumulado sin normalizar, para que la cinta no salte al cruzar el
  /// norte.
  late double _unwrapped = widget.heading;

  @override
  void didUpdateWidget(_AnimatedRibbon oldWidget) {
    super.didUpdateWidget(oldWidget);
    _unwrapped += shortestTurn(oldWidget.heading, widget.heading);
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: _unwrapped),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      builder: (context, heading, child) {
        return CustomPaint(
          size: Size.infinite,
          painter: _RibbonPainter(
            heading: heading,
            scheme: widget.theme.colorScheme,
            degreeStyle: widget.theme.textTheme.labelSmall!,
            cardinalStyle: widget.theme.textTheme.titleMedium!,
          ),
        );
      },
    );
  }
}

class _RibbonPainter extends CustomPainter {
  _RibbonPainter({
    required this.heading,
    required this.scheme,
    required this.degreeStyle,
    required this.cardinalStyle,
  });

  final double heading;
  final ColorScheme scheme;
  final TextStyle degreeStyle;
  final TextStyle cardinalStyle;

  @override
  void paint(Canvas canvas, Size size) {
    final pixelsPerDegree = size.width / HeadingRibbon.fieldOfView;
    final baseline = size.height * 0.78;

    // Capa propia: el difuminado del final se aplica solo sobre la cinta.
    canvas.saveLayer(Offset.zero & size, Paint());

    final minor = Paint()
      ..strokeWidth = 1
      ..color = scheme.onSurface.withValues(alpha: 0.28);
    final medium = Paint()
      ..strokeWidth = 1.5
      ..color = scheme.onSurface.withValues(alpha: 0.55);
    final major = Paint()
      ..strokeWidth = 2
      ..color = scheme.onSurface.withValues(alpha: 0.85);

    final first = (heading - HeadingRibbon.fieldOfView / 2).floor();
    final last = (heading + HeadingRibbon.fieldOfView / 2).ceil();

    for (var degrees = first; degrees <= last; degrees++) {
      if (degrees % 2 != 0) continue;
      final normalized = (degrees % 360 + 360) % 360;
      final x = size.width / 2 + (degrees - heading) * pixelsPerDegree;

      final isCardinal = normalized % 45 == 0;
      final isLabelled = normalized % 15 == 0;
      final height = isCardinal
          ? baseline * 0.62
          : isLabelled
          ? baseline * 0.40
          : baseline * 0.18;
      canvas.drawLine(
        Offset(x, baseline - height),
        Offset(x, baseline),
        isCardinal
            ? major
            : isLabelled
            ? medium
            : minor,
      );

      if (isCardinal) {
        _text(
          canvas,
          cardinalFor(normalized.toDouble()),
          Offset(x, baseline + 6),
          cardinalStyle.copyWith(
            color: normalized == 0 ? scheme.primary : scheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        );
      } else if (isLabelled) {
        _text(
          canvas,
          '$normalized',
          Offset(x, baseline + 9),
          degreeStyle.copyWith(color: scheme.onSurface.withValues(alpha: 0.55)),
        );
      }
    }

    // Marca central fija: el rumbo exacto al que apunta el teléfono.
    final centerX = size.width / 2;
    canvas.drawLine(
      Offset(centerX, 0),
      Offset(centerX, baseline),
      Paint()
        ..strokeWidth = 2
        ..color = scheme.primary,
    );
    final pointer = Path()
      ..moveTo(centerX, baseline - 2)
      ..lineTo(centerX - 7, baseline - 14)
      ..lineTo(centerX + 7, baseline - 14)
      ..close();
    canvas.drawPath(pointer, Paint()..color = scheme.primary);

    // Difuminado en los bordes, para sugerir que la cinta continúa.
    final fade = Paint()
      ..blendMode = BlendMode.dstOut
      ..shader = const LinearGradient(
        colors: [
          Colors.black,
          Colors.transparent,
          Colors.transparent,
          Colors.black,
        ],
        stops: [0, 0.12, 0.88, 1],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, fade);

    canvas.restore();
  }

  void _text(Canvas canvas, String value, Offset anchor, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: value, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, Offset(anchor.dx - painter.width / 2, anchor.dy));
  }

  @override
  bool shouldRepaint(_RibbonPainter oldDelegate) =>
      oldDelegate.heading != heading || oldDelegate.scheme != scheme;
}

/// Indicador de cuánto se apunta por encima o por debajo del horizonte.
class _ElevationBar extends StatelessWidget {
  const _ElevationBar({required this.elevation});

  final double elevation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // -90..90 -> 0..1
    final fraction = ((elevation.clamp(-90.0, 90.0) + 90) / 180).toDouble();
    final rounded = elevation.round();
    final sign = rounded > 0 ? '+' : '';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 22,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.15,
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Align(
                    alignment: Alignment.center,
                    child: Container(
                      width: 1,
                      height: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                  Positioned(
                    left: math.max(0, fraction * constraints.maxWidth - 6),
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        Text(
          'elevación $sign$rounded°',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}
