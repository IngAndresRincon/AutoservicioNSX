using NSXAutoservice.Models.Enum;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace NSXAutoservice.Models.Response
{
    public class FidelidadConsultarResponse
    {
        public bool Success { get; set; }
        public string ClienteId { get; set; }
        public string NombreCliente { get; set; }
        public decimal SaldoActual { get; set; }
        public TipoFidelidadEnum TipoFidelidad { get; set; }
        public string Mensaje { get; set; }
    }
}
