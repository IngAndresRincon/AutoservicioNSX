using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace NSXAutoservice.Models
{
    public class CatalogosModel
    {
        public List<FormaPagoSistemaModel> FormasPagoSistema { get; set; }
        public List<FormaPagoModel> FormasPagoAuto { get; set; }
        public List<ProductoModel> Productos { get; set; }
        public List<string> Colores { get; set; }
        public List<TurnoItemModel> Turnos { get; set; }
    }
}
