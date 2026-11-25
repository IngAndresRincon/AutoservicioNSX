using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace NSXAutoservice.Models.Request
{
    public class MangueraRequest
    {
        public List<MangueraItem> Mangueras { get; set; }
    }

    public class MangueraItem
    {
        public int IdPosicionGrado { get; set; }
        public string Lado { get; set; } // I, D, M
        public string Color { get; set; } // #HEX
    }
}
