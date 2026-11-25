using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using NSXAutoservice.Core;
using NSXAutoservice.Models.Response;
using static System.Runtime.InteropServices.JavaScript.JSType;

namespace NSXAutoServiceAPI.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class MapeoController : ControllerBase
    {
        private readonly Consultas _consultas;

        public MapeoController(Consultas consultas)
        {
            _consultas = consultas;
        }

        [HttpGet("ObtenerMapeo")]
        public IActionResult ObtenerMapeo(string identificador)
        {
            var errores = new List<string>();
            if (string.IsNullOrEmpty(identificador))
            {
                return BadRequest(ApiResponseModel<object>.Ok(null, "Identificador no peude ser null"));
            }
            try
            {
                var data = _consultas.ObtenerMapeo(identificador);
                return Ok(ApiResponseModel<object>.Ok(data, "Mapeo obtenido correctamente"));
            }
            catch (Exception ex)
            {
                return StatusCode(500, ApiResponseModel<object>.Fail(
                    "Error obteniendo mapeo",
                    new List<string> { ex.Message }
                ));
            }
        }

        [HttpGet("ObtenerPrecios")]
        public IActionResult ObtenerPrecios()
        {
            var errores = new List<string>();
            try
            {
                var precios = _consultas.ObtenerPrecios();
                return Ok(ApiResponseModel<object>.Ok(precios, "Precios obtenidos correctamente"));
            }
            catch (Exception ex)
            {
                return StatusCode(500, ApiResponseModel<object>.Fail(
                    "Error obteniendo precios",
                    new List<string> { ex.Message }
                ));
            }
        }
    }
}