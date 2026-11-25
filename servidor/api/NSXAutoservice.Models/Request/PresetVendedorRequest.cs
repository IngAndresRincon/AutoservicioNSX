using NSXAutoservice.Models.Enum;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace NSXAutoservice.Models.Request
{
    public class PresetVendedorRequest
    {
        public string Identificador { get; set; }
        public string Documento { get; set; }

        public int IdPosicion { get; set; }
        public int NumeroManguera { get; set; }
        public TipoProgramacionEnum TipoProgramacion { get; set; }
        public decimal Valor { get; set; }
        public string? Placa { get; set; }
        public double? Km { get; set; }
    }
}
