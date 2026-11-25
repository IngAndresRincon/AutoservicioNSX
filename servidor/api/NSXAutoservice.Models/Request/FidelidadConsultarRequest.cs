using NSXAutoservice.Models.Enum;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace NSXAutoservice.Models.Request
{
    public class FidelidadConsultarRequest
    {
        public string Identificador { get; set; }
        public TipoFidelidadEnum IdTipoFidelidad { get; set; }
        public int TipoDocumento { get; set; }
        public string Documento { get; set; }
    }
}
