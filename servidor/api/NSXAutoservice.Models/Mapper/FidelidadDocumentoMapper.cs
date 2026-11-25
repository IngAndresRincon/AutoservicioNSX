using NSXAutoservice.Models.Enum;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace NSXAutoservice.Models.Mapper
{
    public static class FidelidadDocumentoMapper
    {
        // PUNTOS COLOMBIA
        public static readonly Dictionary<int, string> PuntosColombiaMap = new()
        {
            { 13, "Cedula de Ciudadania" },
            { 22, "Cedula de Extranjeria" },
            { 41, "Pasaporte" },
            { 31, "NIT" },
            { 14, "Tarjeta de Identidad" },
            { 10, "Celular" }
        };

        // VIVE TERPEL
        public static readonly Dictionary<int, string> ViveTerpelMap = new()
        {
            { 1, "cc" },
            { 2, "ce" },
            { 3, "pa" },
            { 4, "nit" },
            { 5, "ti" }
        };

        // COMMODO
        public static readonly Dictionary<int, string> CommodoMap = new()
        {
            { 1, "CC" },
            { 2, "CE" },
            { 3, "PA" },
            { 4, "NIT" },
            { 5, "TI" }
        };

        // LOCAL
        public static readonly Dictionary<int, string> LocalMap = new()
        {
            { 1, "cedula_ciudadania" },
            { 2, "cedula_extranjeria" },
            { 3, "pasaporte" },
            { 4, "nit" },
            { 5, "tarjeta_identidad" }
        };

        // LEAL
        public static readonly Dictionary<int, string> LealMap = new()
        {
            { 1, "CI" },
            { 2, "CE" },
            { 3, "PA" },
            { 4, "NIT" },
            { 5, "TI" }
        };

        // Codigo DIAN que manda la app -> id de tipo de documento que usan F1/F2 en NSX2 y Prime (LifeMiles).
        public static readonly Dictionary<int, int> LifeMilesNsxMap = new()
        {
            { 13, 3 }, // Cedula de ciudadania
            { 22, 4 }, // Cedula de extranjeria
            { 41, 5 }, // Pasaporte
            { 10, 7 }  // Celular
        };

        // F1/F2: Commodo siempre va como celular (7); LifeMiles se traduce desde el codigo DIAN.
        public static int ObtenerTipoDocumentoNsx(TipoFidelidadEnum tipoFidelidad, int tipoDocumentoDian)
        {
            if (tipoFidelidad == TipoFidelidadEnum.Commodo)
                return 7;
            if (tipoFidelidad == TipoFidelidadEnum.LifeMiles)
                return LifeMilesNsxMap.TryGetValue(tipoDocumentoDian, out var id) ? id : throw new ArgumentException("Tipo documento no válido");
            throw new ArgumentException("Programa de fidelidad no soportado");
        }

        public static string ObtenerTipoDocumento(TipoFidelidadEnum tipoFidelidad, int tipoDocumento)
        {
            return tipoFidelidad switch
            {
                TipoFidelidadEnum.PuntosColombia => PuntosColombiaMap.TryGetValue(tipoDocumento, out var pc) ? pc : throw new ArgumentException("Tipo documento no válido"),
                TipoFidelidadEnum.LifeMiles => ViveTerpelMap.TryGetValue(tipoDocumento, out var vt) ? vt : throw new ArgumentException("Tipo documento no válido"),
                TipoFidelidadEnum.Commodo => CommodoMap.TryGetValue(tipoDocumento, out var cmd) ? cmd : throw new ArgumentException("Tipo documento no válido"),
                TipoFidelidadEnum.Local => LocalMap.TryGetValue(tipoDocumento, out var loc) ? loc : throw new ArgumentException("Tipo documento no válido"),
                TipoFidelidadEnum.Leal => LealMap.TryGetValue(tipoDocumento, out var leal) ? leal : throw new ArgumentException("Tipo documento no válido"),
                _ => throw new ArgumentException($"Tipo de fidelidad no soportado")
            };
        }
    }
}
