import 'package:compasstorch/services/selfie_camera.dart';
import 'package:flutter/material.dart';

/// Doble de [SelfieCamera] para los tests: cuenta las veces que se abre, se
/// suelta y se cambia de cámara, y permite simular que falta el permiso, que
/// no hay cámara o que solo hay una, sin tocar el plugin de plataforma.
class FakeSelfieCamera extends ChangeNotifier implements SelfieCamera {
  /// Estado al que llega al abrirse. Cambiarlo simula un permiso denegado o
  /// un dispositivo sin cámara frontal.
  SelfieCameraStatus statusOnStart = SelfieCameraStatus.ready;

  /// El dispositivo tiene las dos cámaras. A `false` simula uno que solo
  /// tiene una, donde no hay nada que alternar.
  bool bothLenses = true;

  int starts = 0;
  int stops = 0;
  int switches = 0;

  SelfieCameraStatus _status = SelfieCameraStatus.off;
  SelfieCameraLens _lens = SelfieCameraLens.front;

  @override
  SelfieCameraStatus get status => _status;

  @override
  SelfieCameraLens get lens => _lens;

  @override
  bool get canSwitchLens => bothLenses;

  @override
  Future<void> switchLens() async {
    switches++;
    _lens = _lens == SelfieCameraLens.front
        ? SelfieCameraLens.back
        : SelfieCameraLens.front;
    notifyListeners();
  }

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
