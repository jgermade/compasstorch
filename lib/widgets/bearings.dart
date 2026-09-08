/// Cuentas de rumbos compartidas por las dos vistas. Los nombres de los ocho
/// rumbos principales están traducidos, así que viven en `AppStrings`.
library;

/// Diferencia más corta entre dos rumbos, en el intervalo (-180, 180].
double shortestTurn(double from, double to) {
  var difference = (to - from) % 360;
  if (difference > 180) difference -= 360;
  if (difference <= -180) difference += 360;
  return difference;
}
