using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace NSXAutoservice.Models
{
    public class EstacionModel
    {
        public string NombreEDS { get; set; }
        public BanderaModel Bandera { get; set; }
        public MarcacionRapidaModel MarcacionesRapidas { get; set; }
        public List<TurnoItemModel> Turnos { get; set; }
        public double MaximoVueltos { get; set; }
    }

    public class MarcacionRapidaModel
    {
        public List<double> Dinero { get; set; }
        public List<double> Volumen { get; set; }
    }
}
