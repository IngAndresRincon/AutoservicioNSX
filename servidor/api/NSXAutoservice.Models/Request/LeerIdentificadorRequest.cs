using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace NSXAutoservice.Models.Request
{
    public class LeerIdentificadorRequest
    {
        public string Identificador { get; set; }
        public int IdPosicion { get; set; }

        /// <summary>Tipo del autoservicio (ver Identificadores del mapeo): 1 iButton, 2 Teclado. La placa (3) no se lee</summary>
        public int Tipo { get; set; }

        /// <summary>Segundos que la peticion espera al identificador antes de rendirse (por defecto 30, maximo 120)</summary>
        public int TimeoutSegundos { get; set; } = 30;
    }
}
