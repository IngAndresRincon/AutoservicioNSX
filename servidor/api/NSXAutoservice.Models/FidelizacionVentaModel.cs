using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace NSXAutoservice.Models
{
    public class FidelizacionVentaModel
    {
        /// <summary>La venta ya tiene una acumulacion de fidelidad exitosa</summary>
        public bool Acumulo { get; set; }
        public DateTime? Fecha { get; set; }

        /// <summary>Programa: 1 PuntosColombia, 2 LifeMiles (ViveTerpel), 3 Commodo, 4 Local, 5 Leal; null si no se registró</summary>
        public int? IdFidelidad { get; set; }
        public string? Programa { get; set; }

        /// <summary>Cliente que acumulo</summary>
        public string? Documento { get; set; }
        public string? Nombre { get; set; }

        /// <summary>Millas o puntos ganados en la venta, si el programa los reporta</summary>
        public double? Acumulado { get; set; }
    }
}
