using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace NSXAutoservice.Models
{
    public class MangueraModel
    {
        public int Numero { get; set; }
        public int IdPosicionGrado { get; set; }
        public ProductoModel Producto { get; set; }
        public string? Lado { get; set; }
        public string? Color { get; set; }
    }
}
