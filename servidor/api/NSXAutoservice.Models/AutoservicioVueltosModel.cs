using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace NSXAutoservice.Models
{
    public class AutoservicioVueltosModel
    {
        public int IdVueltos { get; set; }
        public string Codigo { get; set; }
        public double Valor { get; set; }
        public int? IdDisPosProgramacion { get; set; }
        public int IdEstadoVuelto { get; set; }
        public DateTime FechaCreacion { get; set; }
        public DateTime? FechaUso { get; set; }
        public int? IdTurno { get; set; }
        public int? IdDetalleFormaPago { get; set; }
        public int? IdFormaPago { get; set; }
    }
}
