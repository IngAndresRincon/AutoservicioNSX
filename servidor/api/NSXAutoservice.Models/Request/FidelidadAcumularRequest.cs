using NSXAutoservice.Models.Enum;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace NSXAutoservice.Models.Request
{
    public class FidelidadAcumularRequest
    {
        public string Identificador { get; set; }
        public TipoFidelidadEnum IdTipoFidelidad { get; set;}
        public int IdVenta { get; set; }
        public int TipoDocumento { get; set; }
        public string Documento { get; set; }
        public string? NombreCliente { get; set; }
    }
}
