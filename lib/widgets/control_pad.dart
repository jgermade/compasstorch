import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../theme.dart';
import 'pad_geometry.dart';

/// Mando deslizable: en vez de moverse un pulsador, se desplaza **el fondo**.
///
/// El fondo es una superficie de plástico rugoso con una marca circular
/// translúcida. Sobre él, fijas al marco, dos líneas blancas cruzan el control
/// y delimitan un cuadro de reposo en la esquina inferior derecha. Arrastrar
/// mueve la superficie, y con ella la marca: pasarla por encima de la línea
/// horizontal enciende la linterna, y pasarla a la izquierda de la vertical
/// activa el modo faro.
///
/// La posición dentro de cada eje gradúa la luz: los dos empiezan al mínimo al
/// cruzar su línea y suben al alejarse de ella. Ver [PadGeometry] para el
/// reparto de bandas.
///
/// Mantener el dedo en el cuadro de reposo activa o desactiva que la pantalla
/// se quede encendida; los iconos del mando se apagan a gris cuando deja de
/// estarlo.
class ControlPad extends StatefulWidget {
  const ControlPad({
    super.key,
    required this.torchOn,
    required this.beaconOn,
    required this.torchIntensity,
    required this.beaconLevel,
    required this.torchIsGradual,
    required this.keepAwake,
    required this.onTorchChanged,
    required this.onBeaconChanged,
    required this.onZoneChanged,
    required this.onToggleKeepAwake,
  });

  final bool torchOn;
  final bool beaconOn;

  /// Intensidad y brillo pedidos, de 0 a 1.
  final double torchIntensity;
  final double beaconLevel;

  /// El dispositivo puede regular la intensidad del flash.
  final bool torchIsGradual;

  /// La aplicación está impidiendo que la pantalla se apague sola. Es lo que
  /// dicen los iconos del mando: a color cuando lo impide y en gris cuando no.
  final bool keepAwake;

  /// Estado y nivel de cada control, también durante el arrastre.
  final void Function(bool enabled, double level) onTorchChanged;
  final void Function(bool enabled, double level) onBeaconChanged;

  /// La marca ha entrado o salido de una banda de iluminación. No se llama al
  /// cruzar las líneas: eso ya lo señala el aviso de encendido, más fuerte.
  final VoidCallback onZoneChanged;

  /// Se ha mantenido pulsado el cuadro de reposo el tiempo suficiente.
  final VoidCallback onToggleKeepAwake;

  /// Cuánto hay que mantener el dedo en el cuadro de reposo para cambiar la
  /// inhibición del apagado de pantalla. Es largo a propósito: es un ajuste,
  /// no un control del día a día, y no debe dispararse sin querer.
  static const Duration holdToKeepAwake = Duration(seconds: 5);

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

  /// Cuenta atrás de la pulsación larga sobre el cuadro de reposo.
  Timer? _hold;

  /// La pulsación larga ya ha cambiado el ajuste: al levantar el dedo la marca
  /// no debe moverse como en un toque normal.
  bool _holdFired = false;

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
              // Sin gradación la altura no dice nada: la marca se queda nada
              // más pasada la línea.
              : PadGeometry.torchDimAxis)
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
    _hold?.cancel();
    _settle.dispose();
    _texture?.dispose();
    super.dispose();
  }

  void _animateTo(Offset target, {Offset? from}) {
    _target = target;
    _mark = Tween<Offset>(
      begin: from ?? _position,
      end: target,
    ).animate(CurvedAnimation(parent: _settle, curve: Curves.easeOutCubic));
    _settle.forward(from: 0);
  }

  void _onPanStart(DragStartDetails details) {
    _cancelHold();
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

  /// Empieza a contar la pulsación larga, solo dentro del cuadro de reposo:
  /// ahí dejar el dedo quieto no cambia ninguna luz.
  void _onTapDown(TapDownDetails details) {
    _cancelHold();
    _holdFired = false;
    if (_side <= 0) return;
    final point = details.localPosition / _side;
    if (PadGeometry.torchOn(point.dy) || PadGeometry.beaconOn(point.dx)) return;
    _hold = Timer(ControlPad.holdToKeepAwake, () {
      _hold = null;
      _holdFired = true;
      widget.onToggleKeepAwake();
    });
  }

  void _onTapCancel() {
    _cancelHold();
    _holdFired = false;
  }

  void _cancelHold() {
    _hold?.cancel();
    _hold = null;
  }

  void _onTapUp(TapUpDetails details) {
    _cancelHold();
    // Levantar el dedo después de la pulsación larga solo cierra el gesto: el
    // toque ya se ha gastado en cambiar el ajuste.
    if (_holdFired) {
      _holdFired = false;
      return;
    }
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
    // La animación arranca donde estaba la marca al soltar. Si se dejara que
    // `_animateTo` la leyera después de borrar el arrastre, saldría de
    // `_mark`, que se quedó parado al empezar el gesto, y la marca daría un
    // salto atrás antes de acomodarse.
    final from = _drag ?? _position;
    _drag = null;
    _animateTo(settled, from: from);
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
      // Donde el flash no se puede regular solo hay un nivel, y es el máximo:
      // la altura de la marca no lo cambia.
      widget.torchIsGradual ? PadGeometry.torchIntensity(position.dy) : 1,
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
        0.5 + random.nextDouble() * 1.5,
        Paint()
          ..color = (raised ? Colors.white : Colors.black).withValues(
            alpha: 0.05 + random.nextDouble() * 0.14,
          ),
      );
    }
    return recorder.endRecording();
  }

  /// Tinta de un icono del mando. Sin la inhibición del apagado de pantalla se
  /// pintan en gris: es la señal de que ese ajuste está desactivado.
  Color _iconTint(Color accent) => widget.keepAwake
      ? accent
      : HSLColor.fromColor(accent).withSaturation(0).toColor();

  /// Icono fijo del marco, centrado en [center]. Se enciende cuando su
  /// control está activo.
  Widget _icon(
    IconData icon,
    Offset center,
    Color color,
    double side, {
    required bool active,
  }) {
    final size = side * 0.12;
    return Positioned(
      left: center.dx - size / 2,
      top: center.dy - size / 2,
      child: IgnorePointer(
        child: Icon(
          icon,
          size: size,
          color: color.withValues(alpha: active ? 0.95 : 0.4),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppStrings.of(context);

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
              // El gris de los iconos no lo lee nadie: el estado de la
              // pantalla va en el nombre del mando.
              label: strings.padLabel(keepAwake: widget.keepAwake),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: _onPanStart,
                onPanUpdate: _onPanUpdate,
                onPanEnd: _onPanEnd,
                onTapDown: _onTapDown,
                onTapUp: _onTapUp,
                onTapCancel: _onTapCancel,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _PadPainter(
                          mark: _position,
                          texture: _texture!,
                          scheme: theme.colorScheme,
                        ),
                      ),
                    ),
                    // Un icono por control, en el cuadrante donde solo actúa
                    // ese: la linterna arriba a la derecha y el faro abajo a
                    // la izquierda, cada uno alineado con el cuadro de reposo
                    // por el eje que le toca.
                    _icon(
                      Icons.flashlight_on,
                      Offset(PadGeometry.rest.dx * side, side * 0.1),
                      _iconTint(theme.colorScheme.primary),
                      side,
                      active: widget.torchOn,
                    ),
                    _icon(
                      Icons.brightness_high,
                      Offset(side * 0.1, PadGeometry.rest.dy * side),
                      _iconTint(theme.colorScheme.secondary),
                      side,
                      active: widget.beaconOn,
                    ),
                  ],
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
  });

  final Offset mark;
  final ui.Picture texture;
  final ColorScheme scheme;

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
    // así que la marca aparece justo bajo el dedo.
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

  /// Marca de la superficie: un disco translúcido y plano, que se lee sobre
  /// el grano del plástico sin taparlo.
  void _paintMark(Canvas canvas, Offset center, double side) {
    final radius = side * (PadGeometry.maxBand / 2) * 0.55;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = _ink(
          scheme,
        ).withValues(alpha: scheme.brightness == Brightness.dark ? 0.22 : 0.16),
    );
  }

  /// Marco fijo: las dos líneas que cruzan el mando y delimitan el cuadro de
  /// reposo. No se mueven con la superficie: son contra lo que se compara la
  /// marca.
  void _paintOverlay(Canvas canvas, Size size, double side) {
    final lineX = PadGeometry.line * side;
    final lineY = PadGeometry.line * side;

    // Blancas sobre el plástico oscuro, y oscuras cuando el modo faro aclara
    // el fondo, o desaparecerían. Van translúcidas: marcan el límite sin
    // partir el mando en cuatro cuadros.
    final line = Paint()
      ..strokeWidth = 1.8
      ..color = scheme.brightness == Brightness.dark
          ? Colors.white.withValues(alpha: 0.55)
          : Colors.black.withValues(alpha: 0.3);
    canvas.drawLine(Offset(0, lineY), Offset(size.width, lineY), line);
    canvas.drawLine(Offset(lineX, 0), Offset(lineX, size.height), line);
  }

  @override
  bool shouldRepaint(_PadPainter oldDelegate) =>
      oldDelegate.mark != mark ||
      oldDelegate.scheme != scheme ||
      oldDelegate.texture != texture;
}
