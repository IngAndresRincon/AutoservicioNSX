using Microsoft.AspNetCore.Mvc;
using NSXAutoservice.Models.Enum;
using NSXAutoservice.Models.Request;
using NSXAutoservice.Models.Response;
using NSXAutoServiceAPI.Factories;

// For more information on enabling Web API for empty projects, visit https://go.microsoft.com/fwlink/?LinkID=397860

namespace NSXAutoServiceAPI.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class FidelidadController : ControllerBase
    {
        private readonly IAutoservicioFactory _factory;

        public FidelidadController(IAutoservicioFactory factory)
        {
            _factory = factory;
        }

        [HttpPost("ValidarCliente")]
        public IActionResult ValidarCliente(FidelidadConsultarRequest request) // Cambié nombre del método
        {
            var errores = new List<string>();
            try
            {
                if (string.IsNullOrWhiteSpace(request.Identificador))
                    errores.Add("Identificador es obligatorio");
                if (string.IsNullOrWhiteSpace(request.Documento))
                    errores.Add("Documento es obligatorio");
                if (request.TipoDocumento <= 0)
                    errores.Add("Tipo Documento es obligatorio");

                if (errores.Any())
                    return BadRequest(ApiResponseModel<object>.Fail("Errores de validación", errores));

                var servicio = _factory.CrearServicio();
                var resultado = servicio.ValidarClienteFidelidad(request);

                if (!resultado.Exitoso)
                    return StatusCode(500, ApiResponseModel<object>.Fail(resultado.Mensaje));

                return Ok(ApiResponseModel<object>.Ok(resultado.Data, resultado.Mensaje));
            }
            catch (Exception ex)
            {
                errores.Add(ex.Message);
                return StatusCode(500, ApiResponseModel<object>.Fail(
                    "Error validando cliente de fidelidad",
                    errores
                ));
            }
        }

        [HttpPost("Acumular")]
        public IActionResult Acumular(FidelidadAcumularRequest request)
        {
            var errores = new List<string>();

            try
            {
                if (request.IdVenta <= 0)
                    errores.Add("IdVenta es obligatorio");

                if (string.IsNullOrWhiteSpace(request.Documento))
                    errores.Add("Documento es obligatorio");

                if (request.TipoDocumento <= 0)
                    errores.Add("Tipo Documento es obligatorio");

                if (!Enum.IsDefined(typeof(TipoFidelidadEnum), request.IdTipoFidelidad))
                    errores.Add("Tipo de fidelidad es obligatorio");

                if (errores.Any())
                    return BadRequest(ApiResponseModel<object>.Fail("Errores de validación", errores));

                var servicio = _factory.CrearServicio();
                var resultado = servicio.AcumularFidelidad(request);

                if (!resultado.Exitoso)
                    return StatusCode(500, ApiResponseModel<object>.Fail(resultado.Mensaje));

                return Ok(ApiResponseModel<object>.Ok(resultado.Data, resultado.Mensaje));
            }
            catch (Exception ex)
            {
                errores.Add(ex.Message);

                return StatusCode(500, ApiResponseModel<object>.Fail(
                    "Error acumulando fidelidad",
                    errores
                ));
            }
        }

    }
}
