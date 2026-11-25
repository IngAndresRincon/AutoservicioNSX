using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace NSXAutoservice.Models.Response
{
    public class ResultadoOperacion<T>
    {
        public bool Exitoso { get; set; }
        public T Data { get; set; }
        public string Mensaje { get; set; }
    }
}
