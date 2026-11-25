using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace NSXAutoservice.Models
{
    public class PosicionModel
    {
        public int IdPosicion { get; set; }
        public List<MangueraModel> Mangueras { get; set; }
        public FormatoModel Formato { get; set; }
        public string? CodigoTankio { get; set; }
    }
}
