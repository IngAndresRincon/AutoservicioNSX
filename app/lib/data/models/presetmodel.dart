class Preset {
    final int posicion;
    final int manguera;
    final String tipoProgramacion;
    final int valorProgramado;
    final int precioProducto;

    Preset({
        required this.posicion,
        required this.manguera,
        required this.tipoProgramacion,
        required this.valorProgramado,
        required this.precioProducto,
    });

    factory Preset.fromJson(Map<String, dynamic> json) => Preset(
        posicion: json["Posicion"],
        manguera: json["Manguera"],
        tipoProgramacion: json["TipoProgramacion"],
        valorProgramado: json["ValorProgramado"],
        precioProducto: json["PrecioProducto"],
    );

    Map<String, dynamic> toJson() => {
        "Posicion": posicion,
        "Manguera": manguera,
        "TipoProgramacion": tipoProgramacion,
        "ValorProgramado": valorProgramado,
        "PrecioProducto": precioProducto,
    };
}
