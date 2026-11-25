using System;
using System.Collections.Generic;
using System.Linq;
using System.Runtime.CompilerServices;
using System.Text;
using System.Threading.Tasks;

namespace NSXAutoservice.Models.Request
{
    public class TurnoRequest
    {
        public string Identificador { get; set; }
        public int IdPosicion { get; set; }
        public string Documento { get; set; }
        public string Password { get; set; }

    }
}
