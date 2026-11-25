using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace NSXAutoservice.Models
{
    public class EstadoPresetModel
    {
        public int Estado { get; set; }
        public int? IdPosicion { get; set; }
        public bool VentaZero { get; set; }
        public int IdVenta { get; set; }
    }
}
