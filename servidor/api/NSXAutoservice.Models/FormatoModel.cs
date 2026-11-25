using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace NSXAutoservice.Models
{
    public class FormatoModel
    {
        public int FormatoDinero { get; set; }
        public int FormatoVolumen { get; set; }
        public int FormatoPrecio { get; set; }
        // Digitos del surtidor en esta posicion (6 o 7) y el mayor valor en dinero que acepta (el "Lleno" de NSX)
        public int DigitosPosicion { get; set; }
        public double MaximoDinero { get; set; }
    }
}
