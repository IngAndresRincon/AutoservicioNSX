using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace NSXAutoservice.Models
{
    public class VendedorModel
    {
        public int IdIslero { get; set; }
        public string Cedula { get; set; }
        public string Nombre { get; set; }
        public string Apellidos { get; set; }
        public bool Activo { get; set; }
        // Turno abierto del vendedor en NSX (0 si no tiene); lo llena la validacion del vendedor
        public int IdTurnoAbierto { get; set; }
    }
}
