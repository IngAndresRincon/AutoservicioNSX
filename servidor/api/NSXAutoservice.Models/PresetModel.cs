using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace NSXAutoservice.Models
{
    public class PresetModel
    {
        public int Posicion { get; set; }
        public int Manguera { get; set; }
        public string TipoProgramacion { get; set; }
        public double ValorProgramado { get; set; }
    }
}
