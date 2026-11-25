using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace NSXAutoservice.Models
{
    public class FormaPagoModel
    {
        public int IdFormaPago { get; set; }
        public int IdFormaPagoSistema { get; set; }
        public string Nombre { get; set; }
        public bool Activo { get; set; }
    }
}
