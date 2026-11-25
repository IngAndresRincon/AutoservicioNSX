using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace NSXAutoservice.Models
{
    public class BanderaModel
    {
        public int Id { get; set; }
        public string Petrolera { get; set; }
        public List<string> Colores { get; set; }
    }
}
