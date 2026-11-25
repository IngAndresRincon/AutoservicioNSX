using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace NSXAutoservice.Models.Reportes.DashBoard
{
    public class DashboardResponseModel
    {
        public DashboardKPIModel Kpis { get; set; }
        public ParticipacionModel Participacion { get; set; }
        public List<VentaPorDiaModel> VentasPorDia { get; set; }
        public List<VentaPorProductoModel> VentasPorProducto { get; set; }
        public List<VentaFormaPagoModel> VentasPorFormaPago { get; set; }
        public List<VentaDispensadorModel> VentasPorDispensador { get; set; }
    }

    public class DashboardKPIModel
    {
        public decimal TotalVentas { get; set; }
        public decimal TotalVolumen { get; set; }
        public int TotalTransacciones { get; set; }
        public decimal TicketPromedio { get; set; }
    }

    public class ParticipacionModel
    {
        public decimal VentasEDS { get; set; }
        public decimal VentasAutoservicio { get; set; }
        public decimal VentasTradicional { get; set; }
        public decimal PorcentajeAutoservicio { get; set; }
    }

    public class VentaPorDiaModel
    {
        public DateTime Fecha { get; set; }
        public decimal VentasAutoservicio { get; set; }
        public decimal VentasTradicional { get; set; }
        public decimal VentasTotales { get; set; }
    }

    public class VentaPorProductoModel
    {
        public int IdProducto { get; set; }
        public string NombreProducto { get; set; }
        public decimal Volumen { get; set; }
        public decimal Total { get; set; }
    }

    public class VentaFormaPagoModel
    {
        public int IdFormaPago { get; set; }
        public string FormaPago { get; set; }
        public decimal Total { get; set; }
    }

    public class VentaDispensadorModel
    {
        public int IdDispensador { get; set; }
        public decimal Total { get; set; }
    }


}
