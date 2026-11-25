using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace NSXAutoservice.Models
{
    public class FacturacionRequest
    {
        public int IdVenta { get; set; }
        public string Documento { get; set; }
        public int? TipoDocumento { get; set; }
        public string? RazonSocial { get; set; }
        public string? Email { get; set; }

    }
}
