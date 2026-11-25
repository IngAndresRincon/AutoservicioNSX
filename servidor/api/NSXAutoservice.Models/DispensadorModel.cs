using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace NSXAutoservice.Models
{
    public class DispensadorModel
    {
        public int IdDispensador {  get; set; }
        public int TipoDispensador { get; set; }
        public bool Hibrido { get; set; }
        // null = la base no tiene las columnas; la consola no toca lo que tenga
        public bool? TiempoReal { get; set; }
        public int? IntervaloTiempoReal { get; set; }
        public List<CaraModel> Caras { get; set; }
    }
}
