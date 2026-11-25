using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using NSXAutoservice.Core;
using System.Globalization;

namespace NSXAutoServiceAPI.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class ReportesController : Controller
    {
        private readonly Consultas _consultas;

        public ReportesController(Consultas consultas)
        {
            _consultas = consultas;
        }

        [HttpGet]
        [Route("Dashboard")]
        public IActionResult ObtenerDashboard(string fechaInicio, string fechaFin, int? idDispensador = null, int? idProducto = null)
        {
            try
            {
                var fi = ParseFecha(fechaInicio);
                var ff = ParseFecha(fechaFin);

                if (ff.TimeOfDay == TimeSpan.Zero)
                {
                    ff = ff.Date.AddDays(1).AddMilliseconds(-1);
                }

                var dashboard = _consultas.ObtenerDashboard(
                    fi,
                    ff,
                    idDispensador,
                    idProducto
                );

                return Ok(new
                {
                    success = true,
                    message = "Dashboard obtenido correctamente",
                    data = dashboard
                });
            }
            catch (Exception ex)
            {
                return BadRequest(new
                {
                    success = false,
                    message = ex.Message
                });
            }
        }

        // Ventas del rango con canal, vendedor, cliente, formas de pago y fidelizacion; el reporte filtra y cruza en pantalla
        [HttpGet]
        [Route("Ventas")]
        public IActionResult ObtenerVentas(string fechaInicio, string fechaFin)
        {
            try
            {
                var fi = ParseFecha(fechaInicio);
                var ff = ParseFecha(fechaFin);

                if (ff.TimeOfDay == TimeSpan.Zero)
                {
                    ff = ff.Date.AddDays(1).AddMilliseconds(-1);
                }

                var data = _consultas.ObtenerVentasReporte(fi, ff);

                return Ok(new
                {
                    success = true,
                    message = "Ventas obtenidas correctamente",
                    data
                });
            }
            catch (Exception ex)
            {
                return BadRequest(new
                {
                    success = false,
                    message = ex.Message
                });
            }
        }

        private DateTime ParseFecha(string fecha)
        {
            string[] formatos =
            {
                "yyyyMMdd",
                "yyyy-MM-dd",
                "yyyy-MM-dd HH:mm:ss",
                "yyyy-MM-ddTHH:mm:ss"
            };

            if (DateTime.TryParseExact(
                fecha,
                formatos,
                CultureInfo.InvariantCulture,
                DateTimeStyles.None,
                out DateTime resultado))
            {
                return resultado;
            }

            throw new Exception($"Fecha inválida: {fecha}");
        }
    }
}
