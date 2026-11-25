using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace NSXAutoservice.Core
{
    public class DispositivoModel
    {
        public int? IdDispositivo { get; set; }
        public int IdDispensador { get; set; }
        public string Identificador { get; set; }
        public string? Ip { get; set; }
        public bool? Activo { get; set; }

        /// <summary>El dispositivo permite el acceso de vendedor (Autoservice.Dispositivo.ModoHibrido)</summary>
        public bool? ModoHibrido { get; set; }

        /// <summary>Tipos de identificador de cliente habilitados, banderas "iButton|Teclado|Placa" (por ejemplo "1|0|1")</summary>
        public string? IdentificadoresCliente { get; set; }

        /// <summary>La pantalla muestra valor y avance mientras surte</summary>
        public bool? TiempoReal { get; set; }

        /// <summary>Cada cuanto consulta la pantalla el estado del surtidor (200 a 5000 ms)</summary>
        public int? IntervaloTiempoReal { get; set; }
    }
}
