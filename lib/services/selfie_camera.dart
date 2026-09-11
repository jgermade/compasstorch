import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

/// En qué punto está la vista de la cámara.
enum SelfieCameraStatus {
  /// Suelta: no ocupa la cámara ni la ha pedido.
  off,

  /// Pedida y todavía abriéndose. La primera vez incluye pedir el permiso.
  opening,

  /// Abierta: [SelfieCamera.buildPreview] ya devuelve la imagen.
  ready,

  /// Falta el permiso de cámara.
  denied,

  /// No hay cámara utilizable, o el sistema no ha dejado abrirla.
  unavailable,
}

/// Cuál de las dos cámaras se está viendo en el espejo.
enum SelfieCameraLens {
  /// La de la pantalla: es la que sirve de espejo.
  front,

  /// La de atrás, para mirar lo que hay al otro lado del teléfono.
  back,
}

/// Imagen en directo de la cámara, para usar la pantalla como espejo.
///
/// Es una interfaz por lo mismo que `DeviceServices`: en los tests no hay
/// canales de plataforma, así que se sustituye por un doble. Avisa a sus
/// oyentes cada vez que cambia el [status] o la [lens].
abstract class SelfieCamera implements Listenable {
  SelfieCameraStatus get status;

  /// Cámara que se está viendo, o la que se verá al abrirla.
  SelfieCameraLens get lens;

  /// El dispositivo tiene las dos cámaras, así que [switchLens] lleva a algún
  /// sitio. Hasta que no se abre por primera vez no se sabe, y vale `false`.
  bool get canSwitchLens;

  /// Abre la cámara. La primera vez puede pedir el permiso al sistema.
  Future<void> start();

  /// La suelta, para no dejarla encendida cuando no se está viendo.
  Future<void> stop();

  /// Cambia a la otra cámara. Si está abierta, suelta la actual y abre la
  /// otra; si no, solo deja elegida cuál se abrirá.
  Future<void> switchLens();

  /// La imagen en directo, o `null` mientras no esté lista.
  Widget? buildPreview(BuildContext context);

  void dispose();
}

/// Implementación real sobre el plugin `camera`.
///
/// La vista previa de la cámara frontal llega ya reflejada como un espejo:
/// tanto CameraX en Android como AVFoundation en iOS invierten su imagen. La
/// trasera no se invierte, que es lo que se espera al mirar hacia delante.
class PluginSelfieCamera extends ChangeNotifier implements SelfieCamera {
  CameraController? _controller;
  SelfieCameraStatus _status = SelfieCameraStatus.off;
  SelfieCameraLens _lens = SelfieCameraLens.front;

  /// Las cámaras del dispositivo, una vez preguntadas. Se guardan porque
  /// `availableCameras` tarda y no cambia entre aperturas.
  List<CameraDescription>? _cameras;

  /// La cámara se quiere ver ahora mismo. Sirve para soltar la que termine de
  /// abrirse después de un [stop], que tarda lo suyo en estar lista.
  bool _wanted = false;

  /// Número de la apertura en curso. Al alternar de cámara se pide otra sin
  /// esperar a que termine la anterior: la que llega tarde se descarta en vez
  /// de pisar a la buena.
  int _opening = 0;

  bool _disposed = false;

  @override
  SelfieCameraStatus get status => _status;

  @override
  SelfieCameraLens get lens => _lens;

  @override
  bool get canSwitchLens {
    final cameras = _cameras;
    if (cameras == null) return false;
    bool has(CameraLensDirection direction) =>
        cameras.any((camera) => camera.lensDirection == direction);
    return has(CameraLensDirection.front) && has(CameraLensDirection.back);
  }

  @override
  Future<void> start() async {
    if (_wanted) return;
    _wanted = true;
    await _open();
  }

  @override
  Future<void> stop() async {
    _wanted = false;
    _opening++;
    final controller = _controller;
    _controller = null;
    _moveTo(SelfieCameraStatus.off);
    await controller?.dispose();
  }

  @override
  Future<void> switchLens() async {
    _lens = _lens == SelfieCameraLens.front
        ? SelfieCameraLens.back
        : SelfieCameraLens.front;
    if (!_wanted) {
      _announce();
      return;
    }
    await _open();
  }

  @override
  Widget? buildPreview(BuildContext context) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return null;
    return CameraPreview(controller);
  }

  @override
  void dispose() {
    _disposed = true;
    _wanted = false;
    _opening++;
    final controller = _controller;
    _controller = null;
    controller?.dispose();
    super.dispose();
  }

  /// Abre la cámara elegida, soltando antes la que hubiera: hay dispositivos
  /// que no dejan tener las dos abiertas a la vez.
  Future<void> _open() async {
    final attempt = ++_opening;
    final previous = _controller;
    _controller = null;
    _moveTo(SelfieCameraStatus.opening);
    await previous?.dispose();

    try {
      final cameras = _cameras ??= await availableCameras();
      if (cameras.isEmpty) {
        _finish(attempt, SelfieCameraStatus.unavailable);
        return;
      }
      // Si al dispositivo le falta la cámara pedida se enseña la que haya, que
      // es mejor que un hueco vacío.
      final wanted = _lens == SelfieCameraLens.back
          ? CameraLensDirection.back
          : CameraLensDirection.front;
      final device = cameras.firstWhere(
        (camera) => camera.lensDirection == wanted,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        device,
        // Es un espejo en media pantalla: no hace falta más resolución, y la
        // media gasta bastante menos batería que la máxima.
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();
      if (!_wanted || _disposed || attempt != _opening) {
        // Se ha vuelto a la regla, o se ha pedido la otra cámara, mientras
        // esta se abría: se suelta sin enseñarla.
        await controller.dispose();
        return;
      }
      _controller = controller;
      _moveTo(SelfieCameraStatus.ready);
    } on CameraException catch (error) {
      _finish(
        attempt,
        error.code.startsWith('CameraAccess')
            ? SelfieCameraStatus.denied
            : SelfieCameraStatus.unavailable,
      );
    } catch (_) {
      // Sin plugin de cámara (o sin cámara ninguna) no hay nada que enseñar,
      // pero la aplicación sigue funcionando: se avisa y ya está.
      _finish(attempt, SelfieCameraStatus.unavailable);
    }
  }

  /// Deja el estado del intento [attempt], salvo que ya se haya pedido otra
  /// cosa mientras tanto.
  void _finish(int attempt, SelfieCameraStatus status) {
    if (!_wanted || attempt != _opening) return;
    _moveTo(status);
  }

  void _moveTo(SelfieCameraStatus status) {
    if (_disposed || _status == status) {
      // El estado puede repetirse al alternar de cámara (de `opening` a
      // `opening`), pero la cámara elegida ha cambiado y hay que redibujar.
      _announce();
      return;
    }
    _status = status;
    _announce();
  }

  void _announce() {
    if (!_disposed) notifyListeners();
  }
}
