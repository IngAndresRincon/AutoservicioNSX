using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace NSXAutoservice.Models.Request
{
    public class ConfiguracionAutoservicioRequest
    {
        [Required(ErrorMessage = "Sistema es requerido")]
        [RegularExpression("^(NSX|GNESYS)$", ErrorMessage = "Sistema debe ser 'NSX' o 'GNESYS'")]
        public string Sistema { get; set; }

        [Required(ErrorMessage = "MaxVueltos es requerido")]
        public string MaxVueltos { get; set; }
    }
}
