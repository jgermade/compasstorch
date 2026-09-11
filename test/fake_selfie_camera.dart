import 'package:compasstorch/services/selfie_camera.dart';
import 'package:flutter/material.dart';

/// Doble de [SelfieCamera] para los tests: cuenta las veces que se abre y se
/// suelta, y permite simular que falta el permiso o que no hay cámara, sin
/// tocar el plugin de plataforma.
class FakeSelfieCamera extends ChangeNotifier implements SelfieCamera {
  /// Estado al que llega al abrirse. Cambiarlo simula un permiso denegado o
  /// un dispositivo sin cámara frontal.
  SelfieCameraStatus statusOnStart = SelfieCameraStatus.ready;

  int starts = 0;
  int stops = 0;

  SelfieCameraStatus _status = SelfieCameraStatus.off;

  @override
  SelfieCameraStatus get status => _status;

  @override
  Future<void> start() async {
    starts++;
    _moveTo(statusOnStart);
  }

  @override
  Future<void> stop() async {
    stops++;
    _moveTo(SelfieCameraStatus.off);
  }

  @override
  Widget? buildPreview(BuildContext context) {
    if (_status != SelfieCameraStatus.ready) return null;
    // Como la de verdad: la imagen llega con la proporción de la cámara, más
    // estrecha que alta, y es la vista la que decide cómo encajarla.
    return const AspectRatio(
      aspectRatio: 3 / 4,
      child: SizedBox.expand(key: ValueKey('fakePreview')),
    );
  }

  void _moveTo(SelfieCameraStatus status) {
    if (_status == status) return;
    _status = status;
    notifyListeners();
  }
}
