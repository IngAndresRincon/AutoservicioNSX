using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace NSXAutoservice.Models
{
    /// <summary>Programa de fidelidad configurable en la administración: 1 PuntosColombia, 2 ViveTerpel (LifeMiles), 3 Commodo, 4 Local, 5 Leal</summary>
    public class FidelidadConfigModel
    {
        public int IdFidelidad { get; set; }
        public string? Nombre { get; set; }
        public bool Activo { get; set; }
    }
}
