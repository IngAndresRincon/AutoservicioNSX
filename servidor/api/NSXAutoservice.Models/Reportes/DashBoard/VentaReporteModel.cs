using System;
using System.Collections.Generic;

namespace NSXAutoservice.Models.Reportes.DashBoard
{
    /// <summary>Una venta con todo lo necesario para filtrar y cruzar en el reporte</summary>
    public class VentaReporteModel
    {
        public int IdVenta { get; set; }
        public DateTime Fecha { get; set; }
        public int IdDispensador { get; set; }
        public int IdPosicion { get; set; }
        public int IdProducto { get; set; }
        public string? Producto { get; set; }
        public decimal Volumen { get; set; }
        public decimal Total { get; set; }
        public int TipoTransaccion { get; set; }

        /// <summary>Autoservicio, Vendedor (de paso) o Tradicional</summary>
        public string Canal { get; set; } = "Tradicional";

        public int? IdIslero { get; set; }
        public string? Vendedor { get; set; }
        public string? Cuenta { get; set; }
        public string? Empresa { get; set; }
        public string? Placa { get; set; }

        /// <summary>La venta tiene una acumulación de fidelidad exitosa</summary>
        public bool Fidelizada { get; set; }
        public int? IdFidelidad { get; set; }
        public string? Programa { get; set; }

        public List<FormaPagoVentaReporteModel> FormasPago { get; set; } = new List<FormaPagoVentaReporteModel>();
    }

    public class FormaPagoVentaReporteModel
    {
        public string Nombre { get; set; } = "";
        public decimal Valor { get; set; }
    }

    public class VentasReporteResponseModel
    {
        public List<VentaReporteModel> Ventas { get; set; } = new List<VentaReporteModel>();

        /// <summary>Hay más ventas en el rango que las devueltas (se devuelven las más recientes)</summary>
        public bool Truncado { get; set; }
    }
}
