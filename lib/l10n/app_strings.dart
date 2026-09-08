import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_strings_en.dart';
import 'app_strings_es.dart';

/// Textos de la aplicación traducidos.
///
/// Se escribe a mano en vez de generarse desde ficheros ARB: son pocos textos y
/// así el idioma no añade dependencias ni pasos de compilación. El inglés es el
/// idioma de reserva, por eso encabeza [supportedLocales]: cuando el sistema
/// pide un idioma que no está aquí, `basicLocaleListResolution` se queda con el
/// primero de la lista.
abstract class AppStrings {
  const AppStrings();

  static const List<Locale> supportedLocales = [Locale('en'), Locale('es')];

  static const LocalizationsDelegate<AppStrings> delegate =
      _AppStringsDelegate();

  static AppStrings of(BuildContext context) {
    return Localizations.of<AppStrings>(context, AppStrings) ??
        const AppStringsEn();
  }

  /// Abreviaturas de los ocho rumbos principales, empezando por el norte y
  /// girando en el sentido de las agujas del reloj.
  List<String> get cardinals;

  /// Nombre del rumbo más cercano a [degrees].
  String cardinalFor(double degrees) {
    final normalized = (degrees % 360 + 360) % 360;
    return cardinals[((normalized + 22.5) ~/ 45) % 8];
  }

  /// Nombre de cada vista, solo para lectores de pantalla: en la barra
  /// superior se ve el icono, sin texto.
  String get compassView;
  String get bearingRulerView;

  /// Estado de la linterna y del modo faro, para lectores de pantalla.
  /// [percent] es `null` cuando ese control no se puede graduar.
  String torchState({required bool on, int? percent});
  String beaconState({required bool on, int? percent});

  /// Nivel de la burbuja del centro de la brújula.
  String get levelCentered;
  String get levelOff;

  /// Mientras no hay lecturas fiables del magnetómetro.
  String get calibrating;
  String get calibrateHintFlat;
  String get calibrateHintUpright;

  /// Elevación sobre el horizonte, ya redondeada y con signo.
  String elevation(String degrees);

  /// Avisos de error de los controles.
  String get torchUnavailable;
  String get torchOffFailed;
  String get beaconPartial;
}

class _AppStringsDelegate extends LocalizationsDelegate<AppStrings> {
  const _AppStringsDelegate();

  @override
  bool isSupported(Locale locale) {
    return AppStrings.supportedLocales.any(
      (supported) => supported.languageCode == locale.languageCode,
    );
  }

  @override
  Future<AppStrings> load(Locale locale) {
    return SynchronousFuture<AppStrings>(
      locale.languageCode == 'es' ? const AppStringsEs() : const AppStringsEn(),
    );
  }

  @override
  bool shouldReload(_AppStringsDelegate old) => false;
}
