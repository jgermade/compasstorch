import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../theme.dart';
import 'bearings.dart';
import 'readout.dart';

/// Rosa de los vientos clásica: la carta gira y una aguja fija arriba marca el
/// rumbo. Es la vista que se usa con el teléfono tumbado.
class CompassDial extends StatefulWidget {
  const CompassDial({
    super.key,
    required this.heading,
    this.levelX = 0,
    this.levelY = 0,
    this.onLevelled,
  });

  /// Rumbo magnético del borde superior del teléfono, o `null` si todavía no
  /// hay lectura del magnetómetro.
  final double? heading;

  /// Inclinación del teléfono sobre los ejes de la pantalla, de -1 a 1. Mueve
  /// la burbuja de nivel del centro.
  final double levelX;
  final double levelY;

  /// La burbuja acaba de centrarse. Se avisa solo del cambio, para poder
  /// confirmarlo con un toque háptico sin repetirlo en cada lectura.
  final VoidCallback? onLevelled;

  /// Inclinación, en fracción de la vertical, que desplaza la burbuja hasta el
  /// borde: 0,15 son unos 8,5°.
  static const double levelSpan = 0.15;

  /// Por debajo de esta inclinación (algo más de 1°) se da por nivelado, y no
  /// deja de estarlo hasta pasar de [levelRelease]: sin esa holgura el temblor
  /// de la mano encendería y apagaría el aviso sin parar.
  static const double levelTolerance = 0.02;
  static const double levelRelease = 0.035;

  @override
  State<CompassDial> createState() => _CompassDialState();
}

class _CompassDialState extends State<CompassDial> {
  late bool _levelled = _tiltFor(widget) < CompassDial.levelTolerance;

  static double _tiltFor(CompassDial dial) {
    return math.sqrt(dial.levelX * dial.levelX + dial.levelY * dial.levelY);
  }

  @override
  void didUpdateWidget(CompassDial oldWidget) {
    super.didUpdateWidget(oldWidget);
    final tilt = _tiltFor(widget);
    final was = _levelled;
    _levelled = was
        ? tilt < CompassDial.levelRelease
        : tilt < CompassDial.levelTolerance;
    // Sin rumbo no se ve la burbuja: no hay nada que confirmar.
    if (_levelled && !was && widget.heading != null) widget.onLevelled?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppStrings.of(context);
    final value = widget.heading;

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
                _RotatingCard(
                  heading: value,
                  theme: theme,
                  cardinals: strings.cardinals,
                ),
                Semantics(
                  label: _levelled ? strings.levelCentered : strings.levelOff,
                  child: CustomPaint(
                    size: Size.square(diameter),
                    painter: _HubPainter(
                      color: theme.colorScheme.primary,
                      hubColor: theme.colorScheme.surface,
                      hubBorder: theme.colorScheme.outline,
                      // La burbuja se va hacia el lado que se levanta, como en
                      // un nivel de verdad: la pantalla sube por donde ella va.
                      level: Offset(
                        (widget.levelX / CompassDial.levelSpan).clamp(
                          -1.0,
                          1.0,
                        ),
                        (-widget.levelY / CompassDial.levelSpan).clamp(
                          -1.0,
                          1.0,
                        ),
                      ),
                      levelled: _levelled,
                    ),
                  ),
                ),
                HeadingReadout(heading: value),
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
  const _RotatingCard({
    required this.heading,
    required this.theme,
    required this.cardinals,
  });

  final double heading;
  final ThemeData theme;
  final List<String> cardinals;

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
            cardinals: widget.cardinals,
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
    required this.cardinals,
  });

  final double rotation;
  final ColorScheme scheme;
  final TextStyle textStyle;
  final List<String> cardinals;

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

    for (var index = 0; index < cardinals.length; index++) {
      final degrees = index * 45.0;
      final isNorth = index == 0;
      final label = TextPainter(
        text: TextSpan(
          text: cardinals[index],
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
      oldDelegate.rotation != rotation ||
      oldDelegate.scheme != scheme ||
      oldDelegate.cardinals != cardinals;
}

/// Lo que no gira con la carta: la marca fija de la parte alta, la tapa
/// central y, dentro de ella, la burbuja de nivel.
///
/// La burbuja es un disco translúcido que se pinta **debajo** de la lectura y
/// no llega a tocarla: así indica el nivel sin partir los grados ni el rumbo.
class _HubPainter extends CustomPainter {
  _HubPainter({
    required this.color,
    required this.hubColor,
    required this.hubBorder,
    required this.level,
    required this.levelled,
  });

  final Color color;
  final Color hubColor;
  final Color hubBorder;

  /// Desplazamiento de la burbuja, de -1 a 1 en cada eje de la pantalla.
  final Offset level;

  /// El teléfono está horizontal: se resalta el borde de la tapa.
  final bool levelled;

  /// Radio de la tapa central, en fracción del radio del dial.
  static const double hubFraction = 0.40;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final hubRadius = radius * hubFraction;

    // Tapa central: la lectura numérica va encima de la aguja.
    canvas.drawCircle(center, hubRadius, Paint()..color = hubColor);

    final bubbleRadius = hubRadius * 0.70;
    final travel = hubRadius - bubbleRadius;
    // El desplazamiento viene acotado eje a eje, así que en diagonal la suma
    // de los dos se saldría de la tapa: se recorta también en distancia para
    // que la gota ruede por dentro del borde, como en un nivel de burbuja de
    // verdad, y no asome nunca por fuera.
    var shift = Offset(level.dx * travel, level.dy * travel);
    if (shift.distance > travel) shift = shift / shift.distance * travel;
    final bubble = center + shift;
    // Disco de un solo tono, sin degradado en el borde: la gota se recorta
    // limpia sobre la tapa. Gris y muy translúcido: el nivel es un dato de
    // apoyo, así que se insinúa por el rabillo del ojo y deja los grados y el
    // rumbo, que van encima, como lo único que destaca de la tapa.
    canvas.drawCircle(
      bubble,
      bubbleRadius,
      Paint()..color = AppColors.level.withValues(alpha: 0.2),
    );

    // El borde de la tapa solo cambia de color al centrarse la burbuja: si
    // además engordara, el círculo daría un salto al nivelarse. Es un trazo
    // fino a propósito: solo encuadra la gota, no compite con ella.
    canvas.drawCircle(
      center,
      hubRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = levelled ? color : hubBorder.withValues(alpha: 0.75),
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
  bool shouldRepaint(_HubPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.hubColor != hubColor ||
      oldDelegate.level != level ||
      oldDelegate.levelled != levelled;
}
