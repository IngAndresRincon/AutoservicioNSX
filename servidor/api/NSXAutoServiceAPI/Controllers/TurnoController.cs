using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.DependencyInjection;
using NSXAutoservice.Core;
using NSXAutoservice.Models.Request;
using NSXAutoServiceAPI.Factories;
using NSXAutoservice.Models.Response;

namespace NSXAutoServiceAPI.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class TurnoController : ControllerBase
    {
        private readonly IAutoservicioFactory _factory;


        public TurnoController(IAutoservicioFactory factory)
        {
            _factory = factory;
        }

        [HttpGet("ObtenerTurnoPorId")]
        public IActionResult ObtenerTurnoPorId(int idTurno)
        {
            try
            {
                var consultas = HttpContext.RequestServices.GetRequiredService<Consultas>();
                var data = consultas.ObtenerTurnoPorId(idTurno);

                if (data == null)
                    return NotFound(ApiResponseModel<object>.Fail($"No existe el turno {idTurno}"));

                return Ok(ApiResponseModel<object>.Ok(data, "Turno obtenido correctamente"));
            }
            catch (Exception ex)
            {
                return StatusCode(500, ApiResponseModel<object>.Fail(
                    "Error obteniendo turno",
                    new List<string> { ex.Message }
                ));
            }
        }

        [HttpPost("ValidarVendedor")]
        public IActionResult ValidarVendedor(VendedorRequest request)
        {
            try
            {
                var servicio = _factory.CrearServicio();

                var resultado = servicio.ValidarVendedor(
                    request.Documento,
                    request.Password);

                if (!resultado.Exitoso)
                {
                    return Unauthorized(
                        ApiResponseModel<object>.Fail(
                            resultado.Mensaje));
                }

                return Ok(
                    ApiResponseModel<object>.Ok(
                        resultado.Data,
                        resultado.Mensaje));
            }
            catch (Exception ex)
            {
                return StatusCode(500,
                    ApiResponseModel<object>.Fail(
                        "Error validando vendedor",
                        new List<string> { ex.Message }
                    ));
            }
        }

        [HttpPost("AbrirTurno")]
        public IActionResult AbrirTurno(TurnoRequest request)
        {
            try
            {
                var servicio = _factory.CrearServicio();

                var resultado = servicio.AbrirTurno(request);

                if (!resultado.Exitoso)
                {
                    return Unauthorized(
                        ApiResponseModel<object>.Fail(
                            resultado.Mensaje));
                }

                return Ok(
                    ApiResponseModel<object>.Ok(
                        resultado.Data,
                        resultado.Mensaje));
            }
            catch (Exception ex)
            {
                return StatusCode(500,
                    ApiResponseModel<object>.Fail(
                        "Error abriendo turno",
                        new List<string> { ex.Message }
                    ));
            }
        }

        [HttpPost("CerrarTurno")]
        public IActionResult CerrarTurno(TurnoRequest request)
        {
            try
            {
                var servicio = _factory.CrearServicio();

                var resultado = servicio.CerrarTurno(request);

                if (!resultado.Exitoso)
                {
                    return Unauthorized(
                        ApiResponseModel<object>.Fail(
                            resultado.Mensaje));
                }

                return Ok(
                    ApiResponseModel<object>.Ok(
                        resultado.Data,
                        resultado.Mensaje));
            }
            catch (Exception ex)
            {
                return StatusCode(500,
                    ApiResponseModel<object>.Fail(
                        "Error cerrando turno",
                        new List<string> { ex.Message }
                    ));
            }
        }
    }
}
