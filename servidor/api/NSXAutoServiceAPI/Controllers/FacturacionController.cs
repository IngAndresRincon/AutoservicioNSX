using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using NSXAutoservice.Core;
using NSXAutoservice.Models;
using NSXAutoservice.Models.Response;
using NSXAutoServiceAPI.Factories;

namespace NSXAutoServiceAPI.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class FacturacionController : ControllerBase
    {
        private readonly IAutoservicioFactory _factory;

        public FacturacionController(IAutoservicioFactory factory)
        {
            _factory = factory;
        }

        [HttpGet("ConsultarCliente")]
        public IActionResult ConsultarCliente(string documento)
        {
            var errores = new List<string>();
            try
            {
                var servicio = _factory.CrearServicio();
                var resultado = servicio.ConsultarClienteFE(documento);

                if (!resultado.Exitoso)
                    return StatusCode(500, ApiResponseModel<object>.Fail(resultado.Mensaje));

                return Ok(ApiResponseModel<object>.Ok(resultado.Data, resultado.Mensaje));
            }
            catch (Exception ex)
            {
                return StatusCode(500, ApiResponseModel<object>.Fail(
                    "Error obteniendo cliente",
                    new List<string> { ex.Message }
                ));
            }
        }


        [HttpPost("FacturarVenta")]
        public IActionResult FacturarVenta(FacturacionRequest factura)
        {
            var errores = new List<string>();

            try
            {
                if (factura.IdVenta <= 0)
                    errores.Add("IdVenta es obligatorio");

                if (string.IsNullOrWhiteSpace(factura.Documento))
                    errores.Add("Documento es obligatorio");

                if (errores.Any())
                    return BadRequest(ApiResponseModel<object>.Fail("Errores de validación", errores));

                var servicio = _factory.CrearServicio();

                var resultado = servicio.GenerarFactura(factura);
                if (!resultado.Exitoso)
                    return StatusCode(500, ApiResponseModel<object>.Fail(resultado.Mensaje));

                return Ok(ApiResponseModel<object>.Ok(resultado, "Factura generada correctamente"));
            }
            catch (Exception ex)
            {
                errores.Add(ex.Message);

                return StatusCode(500, ApiResponseModel<object>.Fail(
                    "Error generando factura",
                    errores
                ));
            }
        }
    }
}
