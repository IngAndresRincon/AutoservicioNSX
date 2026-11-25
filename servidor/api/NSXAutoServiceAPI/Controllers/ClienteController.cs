using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using NSXAutoservice.Models.Enum;
using NSXAutoservice.Models.Request;
using NSXAutoservice.Models.Response;
using NSXAutoServiceAPI.Factories;

namespace NSXAutoServiceAPI.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class ClienteController : ControllerBase
    {
        private readonly IAutoservicioFactory _factory;

        public ClienteController(IAutoservicioFactory factory)
        {
            _factory = factory;
        }

        // C1: leer el identificador del cliente; la peticion queda abierta hasta que el MUX lo lee o se agota TimeoutSegundos
        [HttpPost("LeerIdentificador")]
        public IActionResult LeerIdentificador(LeerIdentificadorRequest request)
        {
            var errores = new List<string>();

            if (request == null)
            {
                errores.Add("El request no puede ser nulo");
                return BadRequest(ApiResponseModel<object>.Fail("Request inválido", errores));
            }

            if (request.IdPosicion <= 0)
                errores.Add("IdPosicion es obligatorio");

            if (string.IsNullOrWhiteSpace(request.Identificador))
                errores.Add("Identificador es obligatorio");

            if (request.Tipo < 1 || request.Tipo > 3)
                errores.Add("Tipo debe estar entre 1 y 3");

            if (errores.Any())
                return BadRequest(ApiResponseModel<object>.Fail("Errores de validación", errores));

            try
            {
                var servicio = _factory.CrearServicio();
                var resultado = servicio.LeerIdentificador(request);

                if (!resultado.Exitoso)
                {
                    return BadRequest(ApiResponseModel<object>.Fail(resultado.Mensaje));
                }

                return Ok(ApiResponseModel<object>.Ok(resultado.Data, resultado.Mensaje));
            }
            catch (Exception ex)
            {
                return StatusCode(500, ApiResponseModel<object>.Fail(
                    "Error leyendo el identificador",
                    new List<string> { ex.Message }
                ));
            }
        }

        // C2: autorizar al cliente (credito o prepago local) con el serial leido
        [HttpPost("AutorizarCliente")]
        public IActionResult AutorizarCliente(AutorizarClienteRequest request)
        {
            var errores = new List<string>();

            if (request == null)
            {
                errores.Add("El request no puede ser nulo");
                return BadRequest(ApiResponseModel<object>.Fail("Request inválido", errores));
            }

            if (request.IdPosicion <= 0)
                errores.Add("IdPosicion es obligatorio");

            if (request.NumeroManguera <= 0)
                errores.Add("NumeroManguera es obligatorio");

            if (request.TipoProgramacion != TipoProgramacionEnum.Lleno && request.Valor <= 0)
                errores.Add("Valor es obligatorio");

            if (string.IsNullOrWhiteSpace(request.Serial))
                errores.Add("Serial es obligatorio");

            if (string.IsNullOrWhiteSpace(request.Identificador))
                errores.Add("Identificador es obligatorio");

            if (request.TipoIdentificador < 1 || request.TipoIdentificador > 3)
                errores.Add("TipoIdentificador debe estar entre 1 y 3");

            if (errores.Any())
                return BadRequest(ApiResponseModel<object>.Fail("Errores de validación", errores));

            try
            {
                var servicio = _factory.CrearServicio();
                var resultado = servicio.AutorizarCliente(request);

                if (!resultado.Exitoso)
                {
                    return BadRequest(ApiResponseModel<object>.Fail(resultado.Mensaje));
                }

                return Ok(ApiResponseModel<object>.Ok(resultado.Data, resultado.Mensaje));
            }
            catch (Exception ex)
            {
                return StatusCode(500, ApiResponseModel<object>.Fail(
                    "Error autorizando al cliente",
                    new List<string> { ex.Message }
                ));
            }
        }
    }
}
