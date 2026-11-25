
class ProgrammingResult {
  final int id;
  final int posicionId;
  final int mangueraId;
  final int tipoProgramacion;
  final double valorProgramado;
  final double precio;
  final DateTime fechaRegistro;

  ProgrammingResult({
    required this.id,
    required this.posicionId,
    required this.mangueraId,
    required this.tipoProgramacion,
    required this.valorProgramado,
    required this.precio,
    required this.fechaRegistro,
  });

  factory ProgrammingResult.fromJson(Map<String, dynamic> json) {
    final p = json['content']['programming'];
    return ProgrammingResult(
      id:               p['id'] as int,
      posicionId:       p['posicion_id'] as int,
      mangueraId:       p['manguera_id'] as int,
      tipoProgramacion: p['tipo_programacion'] as int,
      valorProgramado:  double.parse(p['valor_programado'].toString()),
      precio:           double.parse(p['precio'].toString()),
      fechaRegistro:    DateTime.parse(p['fecha_registro']),
    );
  }
}