import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme.dart';
import 'pad_geometry.dart';

/// Mando deslizable: en vez de moverse un pulsador, se desplaza **el fondo**.
///
/// El fondo es una superficie de plástico rugoso con una marca circular
/// grabada. Sobre él, fijas al marco, dos líneas blancas cruzan el control y
/// delimitan un cuadro de reposo en la esquina inferior derecha. Arrastrar
/// mueve la superficie, y con ella la marca: pasarla por encima de la línea
/// horizontal enciende la linterna, y pasarla a la izquierda de la vertical
/// activa el modo faro.
///
/// La posición dentro de cada eje gradúa la luz. Ver [PadGeometry] para el
/// reparto de bandas, que está invertido entre los dos controles.
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
    required this.onZoneChanged,
  });

  final bool torchOn;
  final bool beaconOn;

  /// Intensidad y brillo pedidos, de 0 a 1.
  final double torchIntensity;
  final double beaconLevel;

  /// El dispositivo puede regular la intensidad del flash.
  final bool torchIsGradual;

  /// Estado y nivel de cada control, también durante el arrastre.
  final void Function(bool enabled, double level) onTorchChanged;
  final void Function(bool enabled, double level) onBeaconChanged;

  /// La marca ha entrado o salido de una banda de iluminación. No se llama al
  /// cruzar las líneas: eso ya lo señala el aviso de encendido, más fuerte.
  final VoidCallback onZoneChanged;

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
  late Animation<Offset> _mark = AlwaysStoppedAnimation<Offset>(_target);

  /// Posición de la marca mientras se arrastra, o `null` si no hay arrastre.
  Offset? _drag;

  /// Bandas en las que estaba la marca la última vez que se miró, para avisar
  /// solo de los cambios.
  PadZone _torchZone = PadZone.rest;
  PadZone _beaconZone = PadZone.rest;

  double _side = 0;

  /// Textura del fondo, generada una vez por tamaño: dibujar miles de motas en
  /// cada fotograma del arrastre saldría carísimo.
  ui.Picture? _texture;
  double _textureSide = 0;
  Brightness? _textureBrightness;

  Offset _targetFromWidget() {
    final x = widget.beaconOn
        ? PadGeometry.beaconAxisFor(widget.beaconLevel)
        : PadGeometry.rest.dx;
    final y = widget.torchOn
        ? (widget.torchIsGradual
              ? PadGeometry.torchAxisFor(widget.torchIntensity)
              : PadGeometry.torchFullAxis)
        : PadGeometry.rest.dy;
    return Offset(x, y);
  }

  Offset get _position => _drag ?? _mark.value;

  @override
  void didUpdateWidget(ControlPad oldWidget) {
    super.didUpdateWidget(oldWidget);
    final target = _targetFromWidget();
    // El estado real lo decide el controlador: si rechazó el cambio (por
    // ejemplo, no hay flash), la marca vuelve a donde estaba. Durante el
    // arrastre manda el dedo, no el estado.
    if (target != _target && _drag == null) _animateTo(target);
  }

  @override
  void dispose() {
    _settle.dispose();
    _texture?.dispose();
    super.dispose();
  }

  void _animateTo(Offset target) {
    _target = target;
    _mark = Tween<Offset>(
      begin: _position,
      end: target,
    ).animate(CurvedAnimation(parent: _settle, curve: Curves.easeOutCubic));
    _settle.forward(from: 0);
  }

  void _onPanStart(DragStartDetails details) {
    _settle.stop();
    _torchZone = PadGeometry.torchZone(_position.dy);
    _beaconZone = PadGeometry.beaconZone(_position.dx);
    setState(() => _drag = _position);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_side <= 0) return;
    final current = _drag ?? _position;
    // La marca va con el dedo: el fondo se desplaza con ella.
    final next = Offset(
      (current.dx + details.delta.dx / _side).clamp(0.0, 1.0),
      (current.dy + details.delta.dy / _side).clamp(0.0, 1.0),
    );
    setState(() => _drag = next);
    _emit(next);
  }

  void _onPanEnd(DragEndDetails details) {
    _commit(_drag ?? _position);
  }

  void _onTapUp(TapUpDetails details) {
    if (_side <= 0) return;
    _commit(
      Offset(
        (details.localPosition.dx / _side).clamp(0.0, 1.0),
        (details.localPosition.dy / _side).clamp(0.0, 1.0),
      ),
    );
  }

  void _commit(Offset released) {
    final settled = PadGeometry.settle(
      released,
      torchIsGradual: widget.torchIsGradual,
    );
    _drag = null;
    _animateTo(settled);
    _emit(settled);
  }

  /// Traslada una posición de la marca a estado y nivel de cada control, y
  /// avisa de los cambios de banda.
  void _emit(Offset position) {
    final torchZone = PadGeometry.torchZone(position.dy);
    final beaconZone = PadGeometry.beaconZone(position.dx);

    // Entrar y salir del reposo ya lo señala el aviso de encendido o apagado,
    // que es más fuerte: aquí solo interesan los saltos entre bandas.
    final changed =
        (torchZone != _torchZone &&
            torchZone != PadZone.rest &&
            _torchZone != PadZone.rest) ||
        (beaconZone != _beaconZone &&
            beaconZone != PadZone.rest &&
            _beaconZone != PadZone.rest);

    _torchZone = torchZone;
    _beaconZone = beaconZone;

    widget.onTorchChanged(
      PadGeometry.torchOn(position.dy),
      PadGeometry.torchIntensity(position.dy),
    );
    widget.onBeaconChanged(
      PadGeometry.beaconOn(position.dx),
      PadGeometry.beaconLevel(position.dx),
    );
    if (changed) widget.onZoneChanged();
  }

  /// Motas de plástico rugoso sobre toda la superficie desplazable.
  ui.Picture _buildTexture(double side, ColorScheme scheme) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // La superficie es mayor que el cuadro para que siga cubriéndolo cuando se
    // desplaza hasta el tope.
    final surface = Rect.fromLTWH(-side, -side, side * 3, side * 3);
    canvas.drawRect(surface, Paint()..color = _plastic(scheme));

    // Semilla fija: la misma textura en cada repintado, o el fondo hormiguearía.
    final random = math.Random(20260908);
    final grains = (surface.width * surface.height / 28).round().clamp(
      600,
      24000,
    );
    for (var i = 0; i < grains; i++) {
      final position = Offset(
        surface.left + random.nextDouble() * surface.width,
        surface.top + random.nextDouble() * surface.height,
      );
      // Mitad de las motas iluminadas y mitad en sombra: el grano se lee como
      // relieve en vez de como suciedad.
      final raised = random.nextBool();
      canvas.drawCircle(
        position,
        0.35 + random.nextDouble() * 0.9,
        Paint()
          ..color = (raised ? Colors.white : Colors.black).withValues(
            alpha: 0.02 + random.nextDouble() * 0.055,
          ),
      );
    }
    return recorder.endRecording();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final side = math.min(constraints.maxWidth, constraints.maxHeight);
        _side = side;

        if (_texture == null ||
            _textureSide != side ||
            _textureBrightness != theme.brightness) {
          _texture?.dispose();
          _texture = _buildTexture(side, theme.colorScheme);
          _textureSide = side;
          _textureBrightness = theme.brightness;
        }

        return Center(
          child: SizedBox(
            width: side,
            height: side,
            child: Semantics(
              label: 'Mando de linterna y modo faro',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: _onPanStart,
                onPanUpdate: _onPanUpdate,
                onPanEnd: _onPanEnd,
                onTapUp: _onTapUp,
                child: CustomPaint(
                  painter: _PadPainter(
                    mark: _position,
                    texture: _texture!,
                    scheme: theme.colorScheme,
                    labelStyle: theme.textTheme.labelSmall!,
                    torchOn: widget.torchOn,
                    beaconOn: widget.beaconOn,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Color base de la superficie del mando.
Color _plastic(ColorScheme scheme) => scheme.brightness == Brightness.dark
    ? AppColors.darkPlastic
    : AppColors.lightPlastic;

/// Tinta de contraste sobre la superficie: clara sobre el plástico oscuro y
/// oscura sobre el claro, para que las marcas del marco se vean en los dos
/// temas.
Color _ink(ColorScheme scheme) =>
    scheme.brightness == Brightness.dark ? Colors.white : Colors.black;

class _PadPainter extends CustomPainter {
  _PadPainter({
    required this.mark,
    required this.texture,
    required this.scheme,
    required this.labelStyle,
    required this.torchOn,
    required this.beaconOn,
  });

  final Offset mark;
  final ui.Picture texture;
  final ColorScheme scheme;
  final TextStyle labelStyle;
  final bool torchOn;
  final bool beaconOn;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final frame = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(side * 0.06),
    );

    canvas.save();
    canvas.clipRRect(frame);

    // Superficie móvil: se desplaza lo que se ha separado la marca del reposo,
    // así que la marca grabada aparece justo bajo el dedo.
    final travel = (mark - PadGeometry.rest) * side;
    canvas.save();
    canvas.translate(travel.dx, travel.dy);
    canvas.drawPicture(texture);
    _paintMark(canvas, PadGeometry.rest * side, side);
    canvas.restore();

    _paintOverlay(canvas, size, side);
    canvas.restore();

    canvas.drawRRect(
      frame.deflate(0.75),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = scheme.outline.withValues(alpha: 0.5),
    );
  }

  /// Círculo grabado en la superficie: un rebaje, con la sombra arriba y el
  /// brillo abajo, como si la luz viniera de lo alto.
  void _paintMark(Canvas canvas, Offset center, double side) {
    // Cabe justo dentro de una banda: en los extremos la marca no se sale del
    // cuadro.
    final radius = side * (PadGeometry.maxBand / 2) * 0.92;

    var recess = Color.lerp(
      _plastic(scheme),
      Colors.black,
      scheme.brightness == Brightness.dark ? 0.45 : 0.12,
    )!;
    if (torchOn) recess = Color.lerp(recess, scheme.primary, 0.35)!;
    if (beaconOn) recess = Color.lerp(recess, scheme.secondary, 0.35)!;

    canvas.drawCircle(center, radius, Paint()..color = recess);

    // Rebaje: sombra arriba y luz abajo, como si la luz viniera de lo alto.
    final dark = scheme.brightness == Brightness.dark;
    final bevel = radius * 0.07;
    canvas.drawCircle(
      center.translate(0, -bevel),
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.14
        ..color = Colors.black.withValues(alpha: dark ? 0.45 : 0.22),
    );
    canvas.drawCircle(
      center.translate(0, bevel),
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.14
        ..color = Colors.white.withValues(alpha: dark ? 0.18 : 0.75),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.black.withValues(alpha: 0.25),
    );
  }

  /// Marco fijo: las líneas, las bandas de iluminación y las etiquetas. No se
  /// mueve con la superficie, es contra lo que se compara la marca.
  void _paintOverlay(Canvas canvas, Size size, double side) {
    final lineX = PadGeometry.line * side;
    final lineY = PadGeometry.line * side;
    final band = PadGeometry.maxBand * side;

    // Bandas del 100 %: la del faro en el borde izquierdo y la de la linterna
    // pegada por encima a su línea. Son las dos únicas zonas rellenas, para
    // que se lean de un vistazo, y cada una se queda en su lado de la línea.
    final ink = _ink(scheme);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, band, lineY),
      Paint()..color = ink.withValues(alpha: 0.11),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, lineY - band, lineX, band),
      Paint()..color = ink.withValues(alpha: 0.07),
    );

    // Bandas de iluminación mínima: solo su filo, para no recargar el mando
    // con más rectángulos.
    final edge = Paint()
      ..strokeWidth = 1
      ..color = ink.withValues(alpha: 0.22);
    canvas.drawLine(Offset(0, band), Offset(lineX, band), edge);
    canvas.drawLine(Offset(lineX - band, 0), Offset(lineX - band, lineY), edge);

    // Las líneas que cruzan el control: blancas sobre el plástico oscuro, y
    // oscuras cuando el modo faro aclara el fondo, o desaparecerían.
    final white = Paint()
      ..strokeWidth = 1.8
      ..color = scheme.brightness == Brightness.dark
          ? Colors.white.withValues(alpha: 0.85)
          : Colors.black.withValues(alpha: 0.45);
    canvas.drawLine(Offset(0, lineY), Offset(size.width, lineY), white);
    canvas.drawLine(Offset(lineX, 0), Offset(lineX, size.height), white);

    _label(
      canvas,
      'LINTERNA',
      Offset(lineX - band - 12, lineY - band / 2),
      scheme.primary,
      rightAligned: true,
    );
    _label(
      canvas,
      'FARO',
      Offset(band / 2, lineY + 22),
      scheme.secondary,
      centered: true,
    );
  }

  void _label(
    Canvas canvas,
    String text,
    Offset anchor,
    Color color, {
    bool centered = false,
    bool rightAligned = false,
    double alpha = 0.9,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: labelStyle.copyWith(
          color: color.withValues(alpha: alpha),
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = centered
        ? anchor.dx - painter.width / 2
        : rightAligned
        ? anchor.dx - painter.width
        : anchor.dx;
    painter.paint(canvas, Offset(dx, anchor.dy - painter.height / 2));
  }

  @override
  bool shouldRepaint(_PadPainter oldDelegate) =>
      oldDelegate.mark != mark ||
      oldDelegate.scheme != scheme ||
      oldDelegate.torchOn != torchOn ||
      oldDelegate.beaconOn != beaconOn ||
      oldDelegate.texture != texture;
}
