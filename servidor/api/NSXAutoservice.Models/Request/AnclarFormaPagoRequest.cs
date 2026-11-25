using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace NSXAutoservice.Models.Request
{
    public class AnclarFormaPagoRequest
    {
        public string Documento { get; set; }
        public int IdVenta { get; set; }

        public List<DetalleFormaPagoModel> FormasPago { get; set; }
    }
}
