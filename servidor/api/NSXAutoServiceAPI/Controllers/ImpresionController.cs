using Microsoft.AspNetCore.Mvc;
using NSXAutoservice.Models.Response;
using NSXAutoServiceAPI.Factories;


namespace NSXAutoServiceAPI.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class ImpresionController : ControllerBase
    {
        private readonly IAutoservicioFactory _factory;

        public ImpresionController(IAutoservicioFactory factory)
        {
            _factory = factory;
        }

        [HttpGet("ImprimirVenta")]
        public IActionResult ImprimirVenta(int idVenta)
        {
            var errores = new List<string>();
            try
            {
                if (idVenta <= 0)
                    return BadRequest(ApiResponseModel<object>.Fail("IdVenta inválido"));
                var servicio = _factory.CrearServicio();

                var resultado = servicio.ImprimirVenta(idVenta);

                if (!resultado.Exitoso)
                {
                    return NotFound(ApiResponseModel<object>.Fail(resultado.Mensaje));
                }

                return Ok(ApiResponseModel<object>.Ok(
                    resultado.Data,
                    resultado.Mensaje
                ));
            }
            catch (Exception ex)
            {
                errores.Add(ex.Message);
                return StatusCode(500, ApiResponseModel<int>.Fail("Error interno", errores));
            }
        }
    }
}
