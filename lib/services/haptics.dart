/// Tipos de aviso háptico, de más a menos fuerte.
///
/// La jerarquía importa: encender y apagar tiene que notarse claramente más
/// que moverse entre tramos de intensidad, o los dos avisos se confundirían
/// durante un mismo arrastre.
enum HapticCue {
  /// Un control se ha encendido. El golpe más marcado.
  turnedOn,

  /// Un control se ha apagado.
  turnedOff,

  /// La marca ha entrado o salido de una banda de iluminación. Un tic apenas
  /// perceptible.
  zoneChanged,
}
