using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace NSXAutoservice.Models
{
    public class DispensadorEDSModel
    {
        public int IdDispensador { get; set; }
        public string Marca { get; set; }
        public string Modelo { get; set; }
        public List<CaraModel> Caras { get; set; }
    }
}
