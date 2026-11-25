using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace NSXAutoservice.Models
{
    /// <summary>Tipo de identificador de cliente que ofrece un dispositivo del autoservicio: 1 iButton, 2 Teclado, 3 Placa</summary>
    public class IdentificadorClienteModel
    {
        public int Id { get; set; }
        public string Nombre { get; set; }
    }
}
