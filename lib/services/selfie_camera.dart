import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

/// En qué punto está la vista de la cámara frontal.
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

/// Imagen en directo de la cámara frontal, para usar la pantalla como espejo.
///
/// Es una interfaz por lo mismo que `DeviceServices`: en los tests no hay
/// canales de plataforma, así que se sustituye por un doble. Avisa a sus
/// oyentes cada vez que cambia el [status].
abstract class SelfieCamera implements Listenable {
  SelfieCameraStatus get status;

  /// Abre la cámara. La primera vez puede pedir el permiso al sistema.
  Future<void> start();

  /// La suelta, para no dejarla encendida cuando no se está viendo.
  Future<void> stop();

  /// La imagen en directo, o `null` mientras no esté lista.
  Widget? buildPreview(BuildContext context);

  void dispose();
}

/// Implementación real sobre el plugin `camera`.
///
/// La vista previa llega ya reflejada como un espejo: tanto CameraX en Android
/// como AVFoundation en iOS invierten la imagen de la cámara frontal.
class PluginSelfieCamera extends ChangeNotifier implements SelfieCamera {
  CameraController? _controller;
  SelfieCameraStatus _status = SelfieCameraStatus.off;

  /// La cámara se quiere ver ahora mismo. Sirve para soltar la que termine de
  /// abrirse después de un [stop], que tarda lo suyo en estar lista.
  bool _wanted = false;

  bool _disposed = false;

  @override
  SelfieCameraStatus get status => _status;

  @override
  Future<void> start() async {
    if (_wanted) return;
    _wanted = true;
    _moveTo(SelfieCameraStatus.opening);

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _moveTo(SelfieCameraStatus.unavailable);
        return;
      }
      // Si el dispositivo no tiene cámara frontal se enseña la que haya, que
      // es mejor que un hueco vacío.
      final lens = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        lens,
        // Es un espejo en media pantalla: no hace falta más resolución, y la
        // media gasta bastante menos batería que la máxima.
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();
      if (!_wanted || _disposed) {
        // Se ha vuelto a la regla mientras se abría: se suelta sin enseñarla.
        await controller.dispose();
        return;
      }
      _controller = controller;
      _moveTo(SelfieCameraStatus.ready);
    } on CameraException catch (error) {
      _moveTo(
        error.code.startsWith('CameraAccess')
            ? SelfieCameraStatus.denied
            : SelfieCameraStatus.unavailable,
      );
    } catch (_) {
      // Sin plugin de cámara (o sin cámara ninguna) no hay nada que enseñar,
      // pero la aplicación sigue funcionando: se avisa y ya está.
      _moveTo(SelfieCameraStatus.unavailable);
    }
  }

  @override
  Future<void> stop() async {
    _wanted = false;
    final controller = _controller;
    _controller = null;
    _moveTo(SelfieCameraStatus.off);
    await controller?.dispose();
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
    final controller = _controller;
    _controller = null;
    controller?.dispose();
    super.dispose();
  }

  void _moveTo(SelfieCameraStatus status) {
    if (_disposed || _status == status) return;
    _status = status;
    notifyListeners();
  }
}
