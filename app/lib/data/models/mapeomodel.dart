

class Mapeo {
    final int dispensador;
    final int posicion;
    final int manguera;
    final String nombreProducto;
    final int idProducto;

    Mapeo({
        required this.dispensador,
        required this.posicion,
        required this.manguera,
        required this.nombreProducto,
        required this.idProducto,
    });

    factory Mapeo.fromJson(Map<String, dynamic> json) => Mapeo(
        dispensador: json["Dispensador"],
        posicion: json["Posicion"],
        manguera: json["Manguera"],
        nombreProducto: json["NombreProducto"],
        idProducto: json["IdProducto"],
    );

    static List<Mapeo> fromJsonList(List<dynamic> jsonList) {
      return jsonList
          .map((item) => Mapeo.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    Map<String, dynamic> toJson() => {
        "Dispensador": dispensador,
        "Posicion": posicion,
        "Manguera": manguera,
        "NombreProducto": nombreProducto,
        "IdProducto": idProducto,
    };
}
