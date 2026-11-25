using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace NSXAutoservice.Models.Request
{
    public class CancelarPresetVendedorRequest
    {
        public string Identificador { get; set; }
        public string Documento { get; set; }
        public int IdPosicion { get; set; }
    }
}
