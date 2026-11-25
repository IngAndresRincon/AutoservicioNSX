using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace NSXAutoservice.Models
{
    public class CaraModel
    {
        public int NumeroCara { get; set; }
        public List<PosicionModel> Posiciones { get; set; }
        public string? SerialPantalla { get; set; }
    }
}
