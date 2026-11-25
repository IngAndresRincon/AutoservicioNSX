using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace NSXAutoservice.Models
{
    public class ProductoModel
    {
        public int IdProducto { get; set; }
        public string NombreProducto { get; set; }
        public decimal Precio { get; set; }
        public decimal? PrecioPublico { get; set; } // precio del nivel configurado en la manguera (el que cobra la venta del vendedor)
        public string UnidadMedida { get; set; }
        public decimal? MaximoPreset { get; set; }
    }
}
