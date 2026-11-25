using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace NSXAutoservice.Models.Request
{
    public class FormaPagoAutoRequest
    {
        public int IdFormaPagoAuto { get; set; }
        public int IdFormaPago { get; set; }
        public string Descripcion { get; set; }
        public bool Activo { get; set; }
    }
}
