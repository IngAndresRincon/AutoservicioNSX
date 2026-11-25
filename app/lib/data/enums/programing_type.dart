enum ProgrammingType {
  volumen,
  dinero,
  full
}

extension ProgrammingTypeExtension on ProgrammingType {

  String get label {
    switch (this) {
      case ProgrammingType.volumen:
        return "Por Volumen";
      case ProgrammingType.dinero:
        return "Por Dinero";
      case ProgrammingType.full:
        return "Llenar";
    }
  }

  String get unit {
    switch (this) {
      case ProgrammingType.volumen:
        return "Galones";
      case ProgrammingType.dinero:
        return "Pesos";
      case ProgrammingType.full:
        return "Pesos";
    }
  }
}