import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// Mando deslizable analógico en dos ejes.
///
/// El pulsador descansa en la esquina inferior derecha. Arrastrarlo **hacia
/// arriba** enciende la linterna y arrastrarlo **hacia la izquierda** activa el
/// modo faro; los dos ejes son independientes, así que la esquina superior
/// izquierda deja las dos funciones activas.
///
/// La posición no es solo encendido y apagado: **cuanto más lejos del reposo,
/// más luz**. El pulsador se queda donde se suelte, salvo que caiga por debajo
/// del umbral de activación, y entonces vuelve al reposo. En los dispositivos
/// que no pueden regular el flash, [torchIsGradual] es `false` y el eje
/// vertical vuelve a comportarse como un interruptor.
class ControlPad extends StatefulWidget {
  const ControlPad({
    super.key,
    required this.torchOn,
    required this.beaconOn,
    required this.torchIntensity,
    required this.beaconLevel,
    required this.torchIsGradual,
    required this.onTorchChanged,
    required this.onBeaconChanged,
  });

  /// Fracción del recorrido por debajo de la cual el control está apagado.
  static const double activationThreshold = 0.12;

  final bool torchOn;
  final bool beaconOn;

  /// Intensidad y brillo pedidos, de 0 a 1.
  final double torchIntensity;
  final double beaconLevel;

  /// El dispositivo puede regular la intensidad del flash.
  final bool torchIsGradual;

  /// Se llama con el estado y el nivel cada vez que cambian, también durante el
  /// arrastre.
  final void Function(bool enabled, double level) onTorchChanged;
  final void Function(bool enabled, double level) onBeaconChanged;

  /// Nivel (0 a 1) que corresponde a una posición del eje.
  static double levelForAxis(double axis) {
    return ((axis - activationThreshold) / (1 - activationThreshold)).clamp(
      0.0,
      1.0,
    );
  }

  /// Posición del eje que corresponde a un nivel.
  static double axisForLevel(double level) {
    return activationThreshold +
        level.clamp(0.0, 1.0) * (1 - activationThreshold);
  }

  @override
  State<ControlPad> createState() => _ControlPadState();
}

class _ControlPadState extends State<ControlPad>
    with SingleTickerProviderStateMixin {
  late final AnimationController _settle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  )..addListener(() => setState(() {}));

  late Offset _target = _targetFromWidget();
  late Animation<Offset> _knob = AlwaysStoppedAnimation<Offset>(_target);

  /// Posición normalizada mientras se arrastra: (0,0) = reposo, (1,1) = todo
  /// activo. `null` cuando no hay arrastre en curso.
  Offset? _drag;

  Size _padSize = Size.zero;

  Offset _targetFromWidget() {
    final x = widget.beaconOn
        ? ControlPad.axisForLevel(widget.beaconLevel)
        : 0.0;
    final y = widget.torchOn
        ? (widget.torchIsGradual
              ? ControlPad.axisForLevel(widget.torchIntensity)
              : 1.0)
        : 0.0;
    return Offset(x, y);
  }

  Offset get _position => _drag ?? _knob.value;

  @override
  void didUpdateWidget(ControlPad oldWidget) {
    super.didUpdateWidget(oldWidget);
    final target = _targetFromWidget();
    // El estado real lo decide el controlador: si rechazó el cambio (por
    // ejemplo, no hay flash), el pulsador vuelve a donde estaba. Durante el
    // arrastre manda el dedo, no el estado.
    if (target != _target && _drag == null) _animateTo(target);
  }

  @override
  void dispose() {
    _settle.dispose();
    super.dispose();
  }

  void _animateTo(Offset target) {
    _target = target;
    _knob = Tween<Offset>(
      begin: _position,
      end: target,
    ).animate(CurvedAnimation(parent: _settle, curve: Curves.easeOutCubic));
    _settle.forward(from: 0);
  }

  /// Longitud útil de cada eje en píxeles.
  Offset get _travel {
    final margin = _knobRadius + _padding;
    return Offset(
      math.max(1, _padSize.width - margin * 2),
      math.max(1, _padSize.height - margin * 2),
    );
  }

  double get _knobRadius => math.max(28, _padSize.shortestSide * 0.16);
  double get _padding => 8;

  /// Centro del pulsador en píxeles para una posición normalizada.
  Offset _centerFor(Offset position) {
    final margin = _knobRadius + _padding;
    return Offset(
      lerpDouble(_padSize.width - margin, margin, position.dx)!,
      lerpDouble(_padSize.height - margin, margin, position.dy)!,
    );
  }

  /// Posición normalizada correspondiente a un punto del mando.
  Offset _positionFor(Offset point) {
    final margin = _knobRadius + _padding;
    return Offset(
      ((_padSize.width - margin - point.dx) / _travel.dx).clamp(0.0, 1.0),
      ((_padSize.height - margin - point.dy) / _travel.dy).clamp(0.0, 1.0),
    );
  }

  void _onPanStart(DragStartDetails details) {
    _settle.stop();
    setState(() => _drag = _position);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final current = _drag ?? _position;
    final next = Offset(
      (current.dx - details.delta.dx / _travel.dx).clamp(0.0, 1.0),
      (current.dy - details.delta.dy / _travel.dy).clamp(0.0, 1.0),
    );
    setState(() => _drag = next);
    // La luz sigue al dedo: el controlador se encarga de no saturar el canal.
    _emit(next);
  }

  void _onPanEnd(DragEndDetails details) {
    _commit(_drag ?? _position);
  }

  void _onTapUp(TapUpDetails details) {
    _commit(_positionFor(details.localPosition));
  }

  /// Fija la posición soltada: se queda donde está, salvo que caiga por debajo
  /// del umbral (vuelve al reposo) o que el eje no admita gradación.
  void _commit(Offset released) {
    final threshold = ControlPad.activationThreshold;
    final x = released.dx < threshold ? 0.0 : released.dx;
    final y = released.dy < threshold
        ? 0.0
        : (widget.torchIsGradual ? released.dy : 1.0);

    _drag = null;
    _animateTo(Offset(x, y));
    _emit(Offset(x, y));
  }

  /// Traslada una posición del mando a estado y nivel de cada control.
  void _emit(Offset position) {
    final threshold = ControlPad.activationThreshold;
    widget.onTorchChanged(
      position.dy >= threshold,
      ControlPad.levelForAxis(position.dy),
    );
    widget.onBeaconChanged(
      position.dx >= threshold,
      ControlPad.levelForAxis(position.dx),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final side = math.min(constraints.maxWidth, constraints.maxHeight);
        _padSize = Size(side, side);
        final center = _centerFor(_position);
        final radius = _knobRadius;

        return Center(
          child: SizedBox(
            width: side,
            height: side,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: _onPanStart,
              onPanUpdate: _onPanUpdate,
              onPanEnd: _onPanEnd,
              onTapUp: _onTapUp,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _PadPainter(
                        position: _position,
                        scheme: theme.colorScheme,
                        labelStyle: theme.textTheme.labelSmall!,
                        knobRadius: radius,
                        padding: _padding,
                      ),
                    ),
                  ),
                  Positioned(
                    left: center.dx - radius,
                    top: center.dy - radius,
                    width: radius * 2,
                    height: radius * 2,
                    child: _Knob(
                      radius: radius,
                      torch: _position.dy,
                      beacon: _position.dx,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// El pulsador. Su color mezcla los dos acentos según cuánto se ha desplazado
/// en cada eje, así que el propio botón indica lo que está activo.
class _Knob extends StatelessWidget {
  const _Knob({
    required this.radius,
    required this.torch,
    required this.beacon,
  });

  final double radius;
  final double torch;
  final double beacon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    var color = Color.lerp(
      scheme.surfaceContainerHighest,
      scheme.primary,
      torch,
    )!;
    color = Color.lerp(color, scheme.secondary, beacon * 0.7)!;
    final active = math.max(torch, beacon);

    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(
          color: scheme.onSurface.withValues(alpha: 0.18),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.45 * active),
            blurRadius: 26 * active,
            spreadRadius: 2 * active,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(
        torch >= 0.5
            ? Icons.flashlight_on_rounded
            : beacon >= 0.5
            ? Icons.wb_sunny_rounded
            : Icons.drag_indicator_rounded,
        size: radius * 0.9,
        color: active > 0.5 ? Colors.black87 : scheme.onSurface,
      ),
    );
  }
}

class _PadPainter extends CustomPainter {
  _PadPainter({
    required this.position,
    required this.scheme,
    required this.labelStyle,
    required this.knobRadius,
    required this.padding,
  });

  final Offset position;
  final ColorScheme scheme;
  final TextStyle labelStyle;
  final double knobRadius;
  final double padding;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final radius = Radius.circular(knobRadius + padding);

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, radius),
      Paint()..color = scheme.surfaceContainerHighest.withValues(alpha: 0.55),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(0.75), radius),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = scheme.outline.withValues(alpha: 0.5),
    );

    final margin = knobRadius + padding;
    final home = Offset(size.width - margin, size.height - margin);
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = knobRadius * 1.5
      ..strokeCap = StrokeCap.round
      ..color = scheme.onSurface.withValues(alpha: 0.06);

    // Guías: recorrido vertical (linterna) y horizontal (faro).
    canvas.drawLine(home, Offset(home.dx, margin), trackPaint);
    canvas.drawLine(home, Offset(margin, home.dy), trackPaint);

    _axisLabel(
      canvas,
      'LINTERNA',
      Icons.flashlight_on_rounded,
      Offset(home.dx, margin - padding * 0.5),
      scheme.primary,
      position.dy,
      above: true,
    );
    _axisLabel(
      canvas,
      'FARO',
      Icons.wb_sunny_rounded,
      Offset(margin, home.dy - knobRadius - padding * 1.6),
      scheme.secondary,
      position.dx,
      above: true,
    );

    // Flechas que indican hacia dónde arrastrar.
    _arrow(
      canvas,
      Offset(home.dx, margin + knobRadius * 0.2),
      -math.pi / 2,
      scheme.primary.withValues(alpha: 0.25 + 0.55 * position.dy),
    );
    _arrow(
      canvas,
      Offset(margin + knobRadius * 0.2, home.dy),
      math.pi,
      scheme.secondary.withValues(alpha: 0.25 + 0.55 * position.dx),
    );
  }

  void _axisLabel(
    Canvas canvas,
    String text,
    IconData icon,
    Offset anchor,
    Color color,
    double activation, {
    required bool above,
  }) {
    final blended = Color.lerp(
      color.withValues(alpha: 0.45),
      color,
      activation,
    )!;
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: labelStyle.copyWith(
          color: blended,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.6,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset(anchor.dx - painter.width / 2, anchor.dy - painter.height / 2),
    );
  }

  void _arrow(Canvas canvas, Offset center, double rotation, Color color) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    final path = Path()
      ..moveTo(8, 0)
      ..lineTo(-4, -7)
      ..lineTo(-4, 7)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PadPainter oldDelegate) =>
      oldDelegate.position != position || oldDelegate.scheme != scheme;
}
