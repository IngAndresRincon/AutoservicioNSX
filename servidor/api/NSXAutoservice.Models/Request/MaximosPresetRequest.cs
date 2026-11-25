using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace NSXAutoservice.Models.Request
{
    public class MaximosPresetRequest
    {
        public List<ProductoPresetItem> Productos { get; set; }
    }

    public class ProductoPresetItem
    {
        public int IdProducto { get; set; }
        public decimal MaximoPreset { get; set; }
    }
}
