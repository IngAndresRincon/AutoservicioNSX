using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using NSXAutoservice.Core;
using NSXAutoservice.Models.Request;
using NSXAutoservice.Models.Response;

namespace NSXAutoServiceAPI.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class VentaController : Controller
    {
        private readonly Consultas _consultas;

        public VentaController(Consultas consultas)
        {
            _consultas = consultas;
        }

        [HttpGet("preset/{idPreset}")]
        public IActionResult ObtenerVentaByIdPreset(int idPreset)
        {
            if (idPreset <= 0)
            {
                return BadRequest(
                    ApiResponseModel<object>.Fail("idPreset inválido")
                );
            }

            try
            {
                var venta = _consultas.ObtenerVentaByIdPreset(idPreset);

                if (venta == null)
                {
                    return NotFound(
                        ApiResponseModel<object>.Fail("Venta no encontrada")
                    );
                }

                return Ok(
                    ApiResponseModel<object>.Ok(
                        venta,
                        "Venta obtenida correctamente"
                    )
                );
            }
            catch (Exception ex)
            {
                return StatusCode(500,
                    ApiResponseModel<object>.Fail(
                        "Error obteniendo venta",
                        new List<string> { ex.Message }
                    )
                );
            }
        }

        [HttpPost("AnclarFormaPago")]
        public IActionResult AnclarFormaPago(AnclarFormaPagoRequest request)
        {
            var errores = new List<string>();

            if (request == null)
            {
                errores.Add("El request no puede ser nulo");
                return BadRequest(ApiResponseModel<object>.Fail("Request inválido", errores));
            }

            if (string.IsNullOrWhiteSpace(request.Documento))
                errores.Add("Documento es obligatorio");

            if (request.IdVenta <= 0)
                errores.Add("IdVenta es obligatorio");

            if (request.FormasPago == null || !request.FormasPago.Any())
                errores.Add("Debe enviar al menos una forma de pago");
            else if (request.FormasPago.Any(fp => fp.Valor <= 0))
                errores.Add("Los valores deben ser mayores a 0");

            if (errores.Any())
                return BadRequest(ApiResponseModel<object>.Fail("Errores de validación", errores));

            try
            {
                var resultado = _consultas.AnclarFormasPago(request);

                if (!resultado.Exitoso)
                {
                    return BadRequest(ApiResponseModel<object>.Fail(resultado.Mensaje));
                }

                return Ok(ApiResponseModel<object>.Ok(resultado.Data, resultado.Mensaje));
            }
            catch (Exception ex)
            {
                return StatusCode(500,
                    ApiResponseModel<object>.Fail(
                        "Error anclando formas de pago",
                        new List<string> { ex.Message }
                    )
                );
            }
        }

        [HttpGet("ultima")]
        public IActionResult ObtenerUltimaVenta(int dispensador, int cara)
        {
            if (dispensador <= 0 || cara <= 0)
            {
                return BadRequest(
                    ApiResponseModel<object>.Fail(
                        "dispensador o cara inválidos"
                    )
                );
            }

            try
            {
                var venta = _consultas.ObtenerUltimaVenta(dispensador, cara);

                if (venta == null)
                {
                    return NotFound(
                        ApiResponseModel<object>.Fail(
                            "No se encontró ninguna venta"
                        )
                    );
                }

                return Ok(
                    ApiResponseModel<object>.Ok(
                        venta,
                        "Venta obtenida correctamente"
                    )
                );
            }
            catch (Exception ex)
            {
                return StatusCode(500,
                    ApiResponseModel<object>.Fail(
                        "Error obteniendo última venta",
                        new List<string> { ex.Message }
                    )
                );
            }
        }

    }
}
