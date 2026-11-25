using NSXAutoservice.Models.Enum;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace NSXAutoservice.Models.Request
{
    public class AutorizarClienteRequest
    {
        public string Identificador { get; set; }
        public int IdPosicion { get; set; }
        public int NumeroManguera { get; set; }
        public TipoProgramacionEnum TipoProgramacion { get; set; }
        public decimal Valor { get; set; }
        public double? Km { get; set; }

        /// <summary>Serial leido con LeerIdentificador; con tipo 2 el codigo del cliente y con tipo 3 la placa</summary>
        public string Serial { get; set; }

        /// <summary>Clave del cliente; obligatoria solo para el teclado (tipo 2)</summary>
        public string? Clave { get; set; }

        /// <summary>Tipo del autoservicio (ver Identificadores del mapeo): 1 iButton, 2 Teclado, 3 Placa</summary>
        public int TipoIdentificador { get; set; }

        /// <summary>Opcional: documento del vendedor; la venta va a su turno abierto. Sin el, va al turno abierto de la isla</summary>
        public string? Documento { get; set; }
    }
}
