using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace NSXAutoservice.Models
{
    public class VentaModel
    {
        public int IdVenta { get; set; }
        public DateTime FechaVenta { get; set; }
        public double Dinero { get; set; }
        public double Volumen { get; set; }
        public double TotalDineroInicial { get; set; }
        public double TotalDineroFinal { get; set; }
        public double TotalVolumenInicial { get; set; }
        public double TotalVolumenFinal { get; set; }
        public double ValorProgramado { get; set; }
        public int TipoProgramacion { get; set; }
        public int IdPosicion { get; set; }
        public int NumeroManguera { get; set; }
        public double PrecioVenta { get; set; }
        public int IdProgramacion { get; set; }
        public int IdProducto { get; set; }
        public int TipoTransaccion { get; set; }
        public int Vuelto { get; set; }
        public bool VueltoRegistrado { get; set; }
        public string? FElectronica { get; set; }
        public FidelizacionVentaModel Fidelizacion { get; set; } = new FidelizacionVentaModel();
        public ClienteVentaModel? Cliente { get; set; }
        public List<FormaPagoRegistradaModel> FormasPago { get; set; } = new List<FormaPagoRegistradaModel>();
    }
}
