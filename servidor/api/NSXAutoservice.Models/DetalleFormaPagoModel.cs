using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace NSXAutoservice.Models
{
    public class DetalleFormaPagoModel
    {
        public int IdFormaPago { get; set; }
        public double Valor { get; set; }
        public string? Identificador { get; set; }
    }
}
