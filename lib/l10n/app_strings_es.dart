import 'app_strings.dart';

/// Textos en castellano.
class AppStringsEs extends AppStrings {
  const AppStringsEs();

  @override
  List<String> get cardinals => const [
    'N',
    'NE',
    'E',
    'SE',
    'S',
    'SO',
    'O',
    'NO',
  ];

  @override
  String get compassView => 'En horizontal: brújula';

  @override
  String get bearingRulerView => 'En vertical: regla de rumbos';

  @override
  String torchState({required bool on, int? percent}) {
    if (!on) return 'Linterna apagada';
    return percent == null
        ? 'Linterna encendida'
        : 'Linterna encendida al $percent por ciento';
  }

  @override
  String beaconState({required bool on, int? percent}) {
    if (!on) return 'Faro apagado';
    return percent == null
        ? 'Faro encendido'
        : 'Faro encendido al $percent por ciento';
  }

  @override
  String padLabel({required bool keepAwake}) {
    const pad = 'Mando de linterna y modo faro.';
    return keepAwake
        ? '$pad La pantalla no se apaga sola; mantén pulsado el cuadro de '
              'reposo para permitir que se apague.'
        : '$pad La pantalla puede apagarse sola; mantén pulsado el cuadro de '
              'reposo para impedirlo.';
  }

  @override
  String get levelCentered => 'Teléfono nivelado';

  @override
  String get levelOff => 'Teléfono inclinado';

  @override
  String get calibrating => 'Buscando el campo magnético…';

  @override
  String get calibrateHintFlat =>
      'Mueve el teléfono dibujando un ocho para calibrar la brújula.';

  @override
  String get calibrateHintUpright =>
      'Levanta el teléfono y muévelo dibujando un ocho para calibrar.';

  @override
  String elevation(String degrees) => 'elevación $degrees';

  @override
  String get torchUnavailable =>
      'No se ha podido encender la linterna: este dispositivo no tiene flash '
      'disponible o lo está usando otra aplicación.';

  @override
  String get torchOffFailed => 'No se ha podido apagar la linterna.';

  @override
  String get beaconPartial =>
      'El modo faro se ha activado solo en parte: el sistema no ha permitido '
      'ajustar el brillo o mantener la pantalla encendida.';
}
