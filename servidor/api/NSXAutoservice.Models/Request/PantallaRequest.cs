using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace NSXAutoservice.Models.Request
{
    public class PantallaRequest
    {
        public int IdPosicion { get; set; }
        public string? SerialPantalla { get; set; }
        public string? CodigoTankio { get; set; } 
    }
}
