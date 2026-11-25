using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace NSXAutoservice.Models
{
    public class VentaFacturaModel
    {
        public int idVenta { get; set;}
        public string? FacturaElectronica { get; set;}
        public bool? Sincronizado { get; set;}
    }
}
