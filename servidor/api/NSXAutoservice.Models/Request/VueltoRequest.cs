using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace NSXAutoservice.Models.Request
{
    public class VueltoRequest
    {
        public int IdPreset { get; set; }
        public double Valor { get; set; }
        public int IdFormaPago { get; set; }
    }
}
