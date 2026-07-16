import 'package:flutter/material.dart';

// Proporción real de una cancha (105m x 68m), en vertical: el ancho de la
// cancha se ve en el ancho de pantalla y el largo en el alto, a diferencia
// del fondo de la intro (que la dibuja horizontal, tipo toma de estadio).
const double kPitchAspect = 68 / 105; // width / height

// Encaja el rectángulo de la cancha (con [kPitchAspect]) dentro del espacio
// disponible [s], dejando un margen lateral y sin superar [maxHeightFraction]
// del alto disponible (para no invadir encabezado/áreas seguras).
Rect computePitchRect(Size s, {double maxHeightFraction = 0.94}) {
  var w = s.width * 0.92;
  var h = w / kPitchAspect;
  final maxH = s.height * maxHeightFraction;
  if (h > maxH) {
    h = maxH;
    w = h * kPitchAspect;
  }
  return Rect.fromLTWH((s.width - w) / 2, (s.height - h) / 2, w, h);
}
