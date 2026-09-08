/// Abreviaturas de los ocho rumbos principales, en castellano.
const List<String> kCardinalNames = ['N', 'NE', 'E', 'SE', 'S', 'SO', 'O', 'NO'];

/// Nombre del rumbo más cercano a [degrees].
String cardinalFor(double degrees) {
  final normalized = (degrees % 360 + 360) % 360;
  final index = ((normalized + 22.5) ~/ 45) % 8;
  return kCardinalNames[index];
}

/// Diferencia más corta entre dos rumbos, en el intervalo (-180, 180].
double shortestTurn(double from, double to) {
  var difference = (to - from) % 360;
  if (difference > 180) difference -= 360;
  if (difference <= -180) difference += 360;
  return difference;
}
