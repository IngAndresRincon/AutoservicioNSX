using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace NSXAutoservice.Models.Request
{
    public class RegistrarVueltoRequest
    {
        public string Codigo { get; set; }
        public double Valor { get; set; }
        public int IdDisPosProgramacion { get; set; }
        public DateTime FechaCreacion { get; set; }
        public DateTime? FechaUso { get; set; }
        public int IdFormaPago { get; set; }
    }
}
