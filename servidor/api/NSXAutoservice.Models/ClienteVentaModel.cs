using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace NSXAutoservice.Models
{
    /// <summary>Cuenta y vehículo de una venta con cliente (prepago, crédito, etc.); no aplica a efectivo</summary>
    public class ClienteVentaModel
    {
        public string? Cuenta { get; set; }
        public string? Empresa { get; set; }
        public string? Placa { get; set; }
        public double? Kilometraje { get; set; }
    }
}
