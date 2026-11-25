using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace NSXAutoservice.Models
{
    public class MapeoModel
    {
        public EstacionModel Estacion { get; set; }
        public List<DispensadorModel> Dispensadores { get; set; }
        public List<FormaPagoModel> FormasPago { get; set; }
        public List<FormaPagoModel> FormasPagoVendedor { get; set; }
        public List<FidelidadModel> Fidelidad { get; set; }
        public List<IdentificadorClienteModel> Identificadores { get; set; }
    }
}
