class Estado {
    final int idPosicion;
    final String estado;
    final String dinero;
    final String volumen;
    final String numeroManguera;

    Estado({
        required this.idPosicion,
        required this.estado,
        required this.dinero,
        required this.volumen,
        required this.numeroManguera,
    });

    factory Estado.fromJson(Map<String, dynamic> json) => Estado(
        idPosicion: json["IdPosicion"],
        estado: json["Estado"],
        dinero: json["Dinero"],
        volumen: json["Volumen"],
        numeroManguera: json["NumeroManguera"],
    );

    Map<String, dynamic> toJson() => {
        "IdPosicion": idPosicion,
        "Estado": estado,
        "Dinero": dinero,
        "Volumen": volumen,
        "NumeroManguera": numeroManguera,
    };
}
