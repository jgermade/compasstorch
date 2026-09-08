import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'cardinals.dart';
import 'readout.dart';

/// Rosa de los vientos clásica: la carta gira y una aguja fija arriba marca el
/// rumbo. Es la vista que se usa con el teléfono tumbado.
class CompassDial extends StatelessWidget {
  const CompassDial({super.key, required this.heading});

  /// Rumbo magnético del borde superior del teléfono, o `null` si todavía no
  /// hay lectura del magnetómetro.
  final double? heading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = heading;

    if (value == null) {
      return const SensorPlaceholder();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Un pelín más pequeña que el hueco disponible, para que respire.
        final diameter =
            math.min(constraints.maxWidth, constraints.maxHeight) * 0.88;
        return Center(
          child: SizedBox(
            width: diameter,
            height: diameter,
            child: Stack(
              alignment: Alignment.center,
              children: [
                _RotatingCard(heading: value, theme: theme),
                CustomPaint(
                  size: Size.square(diameter),
                  painter: _NeedlePainter(
                    color: theme.colorScheme.primary,
                    hubColor: theme.colorScheme.surface,
                    hubBorder: theme.colorScheme.outline,
                  ),
                ),
                HeadingReadout(heading: value, label: 'rumbo'),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Anima el giro de la carta por el camino más corto, sin dar la vuelta entera
/// al cruzar el norte.
class _RotatingCard extends StatefulWidget {
  const _RotatingCard({required this.heading, required this.theme});

  final double heading;
  final ThemeData theme;

  @override
  State<_RotatingCard> createState() => _RotatingCardState();
}

class _RotatingCardState extends State<_RotatingCard> {
  /// Ángulo acumulado sin normalizar, para que 359° -> 1° gire 2° y no -358°.
  late double _unwrapped = widget.heading;

  @override
  void didUpdateWidget(_RotatingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _unwrapped += shortestTurn(oldWidget.heading, widget.heading);
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: _unwrapped),
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOut,
      builder: (context, angle, child) {
        return CustomPaint(
          size: Size.infinite,
          painter: _DialPainter(
            rotation: -angle * math.pi / 180,
            scheme: widget.theme.colorScheme,
            textStyle: widget.theme.textTheme.titleMedium!,
          ),
        );
      },
    );
  }
}

class _DialPainter extends CustomPainter {
  _DialPainter({
    required this.rotation,
    required this.scheme,
    required this.textStyle,
  });

  final double rotation;
  final ColorScheme scheme;
  final TextStyle textStyle;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;

    canvas.drawCircle(
      center,
      radius - 1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = scheme.outline.withValues(alpha: 0.6),
    );
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);

    final minorTick = Paint()
      ..strokeWidth = 1
      ..color = scheme.onSurface.withValues(alpha: 0.35);
    final majorTick = Paint()
      ..strokeWidth = 2
      ..color = scheme.onSurface.withValues(alpha: 0.75);

    for (var degrees = 0; degrees < 360; degrees += 5) {
      final isMajor = degrees % 45 == 0;
      final isMedium = degrees % 15 == 0;
      final length = isMajor
          ? radius * 0.12
          : isMedium
          ? radius * 0.08
          : radius * 0.045;
      final angle = (degrees - 90) * math.pi / 180;
      final outer = Offset(math.cos(angle), math.sin(angle)) * (radius - 4);
      final inner =
          Offset(math.cos(angle), math.sin(angle)) * (radius - 4 - length);
      canvas.drawLine(
        inner,
        outer,
        isMajor || isMedium ? majorTick : minorTick,
      );
    }

    for (var index = 0; index < kCardinalNames.length; index++) {
      final degrees = index * 45.0;
      final isNorth = index == 0;
      final label = TextPainter(
        text: TextSpan(
          text: kCardinalNames[index],
          style: textStyle.copyWith(
            color: isNorth ? scheme.primary : scheme.onSurface,
            fontWeight: isNorth ? FontWeight.w800 : FontWeight.w600,
            fontSize: textStyle.fontSize! * (isNorth ? 1.25 : 1),
            letterSpacing: 0.5,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final angle = (degrees - 90) * math.pi / 180;
      final position =
          Offset(math.cos(angle), math.sin(angle)) * (radius * 0.76);
      canvas.save();
      canvas.translate(position.dx, position.dy);
      // La carta gira con las letras, como en una brújula real.
      label.paint(canvas, Offset(-label.width / 2, -label.height / 2));
      canvas.restore();
    }

    // Aguja alrededor del cubo central: la punta de color marca el norte
    // magnético y la cola, atenuada, el sur.
    canvas.drawPath(
      _arrow(radius, tip: 0.72, base: 0.45, halfWidth: 0.055),
      Paint()..color = scheme.primary,
    );
    canvas.drawPath(
      _arrow(radius, tip: -0.66, base: -0.45, halfWidth: 0.05),
      Paint()..color = scheme.onSurface.withValues(alpha: 0.32),
    );

    canvas.restore();
  }

  /// Punta de la aguja. Las distancias van en fracción del radio y son
  /// negativas hacia el sur.
  Path _arrow(
    double radius, {
    required double tip,
    required double base,
    required double halfWidth,
  }) {
    return Path()
      ..moveTo(0, -radius * tip)
      ..lineTo(radius * halfWidth, -radius * base)
      ..lineTo(-radius * halfWidth, -radius * base)
      ..close();
  }

  @override
  bool shouldRepaint(_DialPainter oldDelegate) =>
      oldDelegate.rotation != rotation || oldDelegate.scheme != scheme;
}

/// Marca fija en la parte alta del dial: señala el rumbo actual.
class _NeedlePainter extends CustomPainter {
  _NeedlePainter({
    required this.color,
    required this.hubColor,
    required this.hubBorder,
  });

  final Color color;
  final Color hubColor;
  final Color hubBorder;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;

    // Tapa central: la lectura numérica va encima de la aguja.
    canvas.drawCircle(center, radius * 0.40, Paint()..color = hubColor);
    canvas.drawCircle(
      center,
      radius * 0.40,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = hubBorder.withValues(alpha: 0.35),
    );

    final tip = Offset(center.dx, center.dy - radius + 2);
    final marker = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(tip.dx - 9, tip.dy - 14)
      ..lineTo(tip.dx + 9, tip.dy - 14)
      ..close();
    canvas.drawPath(marker, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_NeedlePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.hubColor != hubColor;
}
