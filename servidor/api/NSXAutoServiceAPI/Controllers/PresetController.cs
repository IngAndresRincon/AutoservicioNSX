using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using NSXAutoservice.Core;
using NSXAutoservice.Models.Enum;
using NSXAutoservice.Models.Request;
using NSXAutoservice.Models.Response;
using NSXAutoServiceAPI.ComunicacionSocket;
using NSXAutoServiceAPI.Factories;
using System.Diagnostics;
using System.Transactions;

namespace NSXAutoServiceAPI.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class PresetController : ControllerBase
    {
        private readonly IAutoservicioFactory _factory;

        public PresetController(IAutoservicioFactory factory)
        {
            _factory = factory;
        }

        [HttpPost("Preset")]
        public IActionResult EnviarPreset(PresetRequest preset)
        {
            var errores = new List<string>();

            try
            {
                if (preset == null)
                {
                    errores.Add("El request no puede ser nulo");
                    return BadRequest(ApiResponseModel<object>.Fail("Request inválido", errores));
                }

                if (preset.FormasPago == null || !preset.FormasPago.Any())
                    errores.Add("Debe enviar al menos una forma de pago");

                if (preset.FormasPago.Any(fp => fp.Valor <= 0))
                    errores.Add("Los valores deben ser mayores a 0");

                decimal total = (decimal)preset.FormasPago.Sum(fp => fp.Valor);

                if (total != preset.ValorDinero)
                    errores.Add("La suma debe ser igual al valor del preset");

                if (preset.IdPosicion <= 0)
                    errores.Add("IdPosicion es obligatorio");

                if (preset.NumeroManguera <= 0)
                    errores.Add("NumeroManguera es obligatorio");

                if (preset.TipoProgramacion != TipoProgramacionEnum.Lleno && preset.Valor <= 0)
                    errores.Add("Valor es obligatorio");

                if (errores.Any())
                    return BadRequest(ApiResponseModel<object>.Fail("Errores de validación", errores));

                var servicio = _factory.CrearServicio();

                var resultado = servicio.CrearPreset(preset);

                if (!resultado.Exitoso)
                {
                    //servicio.CancelarPreset(preset);

                    return StatusCode(500, ApiResponseModel<object>.Fail(
                        "No se pudo realizar la programación del preset",
                        new List<string> { resultado.Mensaje }
                    ));
                }

                int idPreset = resultado.Data;

                return Ok(ApiResponseModel<object>.Ok(new { idPreset }, "Preset creado correctamente"));
            }
            catch (Exception ex)
            {
                errores.Add(ex.Message);

                return StatusCode(500, ApiResponseModel<object>.Fail("Error interno", errores));
            }
        }

        [HttpPost("PresetVendedor")]
        public IActionResult EnviarPresetVendedor(PresetVendedorRequest preset)
        {
            var errores = new List<string>();

            try
            {
                if (preset == null)
                {
                    errores.Add("El request no puede ser nulo");
                    return BadRequest(ApiResponseModel<object>.Fail("Request inválido", errores));
                }

                if (string.IsNullOrWhiteSpace(preset.Documento))
                    errores.Add("Documento es obligatorio");

                if (preset.IdPosicion <= 0)
                    errores.Add("IdPosicion es obligatorio");

                if (preset.NumeroManguera <= 0)
                    errores.Add("NumeroManguera es obligatorio");

                if (preset.TipoProgramacion != TipoProgramacionEnum.Lleno && preset.Valor <= 0)
                    errores.Add("Valor es obligatorio");

                if (errores.Any())
                    return BadRequest(ApiResponseModel<object>.Fail("Errores de validación", errores));

                var servicio = _factory.CrearServicio();

                var resultado = servicio.CrearPresetVendedor(preset);

                if (!resultado.Exitoso)
                {
                    return StatusCode(500, ApiResponseModel<object>.Fail(
                        "No se pudo realizar la programación del preset",
                        new List<string> { resultado.Mensaje }
                    ));
                }

                int idPreset = resultado.Data;

                return Ok(ApiResponseModel<object>.Ok(new { idPreset }, "Preset creado correctamente"));
            }
            catch (Exception ex)
            {
                errores.Add(ex.Message);

                return StatusCode(500, ApiResponseModel<object>.Fail("Error interno", errores));
            }
        }

        [HttpPost("CancelarPreset")]
        public IActionResult CancelarPresetVendedor(CancelarPresetVendedorRequest request)
        {
            var errores = new List<string>();

            if (request == null)
            {
                errores.Add("El request no puede ser nulo");
                return BadRequest(ApiResponseModel<object>.Fail("Request inválido", errores));
            }

            if (string.IsNullOrWhiteSpace(request.Documento))
                errores.Add("Documento es obligatorio");

            if (request.IdPosicion <= 0)
                errores.Add("IdPosicion es obligatorio");

            if (errores.Any())
                return BadRequest(ApiResponseModel<object>.Fail("Errores de validación", errores));

            try
            {
                var servicio = _factory.CrearServicio();

                var resultado = servicio.CancelarPresetVendedor(request);

                if (!resultado.Exitoso)
                {
                    return BadRequest(ApiResponseModel<object>.Fail(resultado.Mensaje));
                }

                return Ok(ApiResponseModel<object>.Ok(null, resultado.Mensaje));
            }
            catch (Exception ex)
            {
                return StatusCode(500, ApiResponseModel<object>.Fail(
                    "Error cancelando el preset",
                    new List<string> { ex.Message }
                ));
            }
        }

        [HttpGet("EstadoPreset")]
        public IActionResult EstadoPreset(int idPreset)
        {
            var errores = new List<string>();
            object venta = null;
            try
            {
                if (idPreset <= 0)
                    return BadRequest(ApiResponseModel<object>.Fail("IdPreset inválido"));
                var servicio = _factory.CrearServicio();

                var resultado = servicio.ObtenerEstadoPreset(idPreset);

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

        [HttpGet("ObtenerEstado")]
        public IActionResult ObtenerEstado(int idPosicion)
        {
            try
            {
                if (idPosicion <= 0)
                    return BadRequest(ApiResponseModel<object>.Fail("IdPosicion inválido"));

                var servicio = _factory.CrearServicio();
                var resultado = servicio.ObtenerEstado(idPosicion);

                if (!resultado.Exitoso)
                    return BadRequest(ApiResponseModel<object>.Fail(resultado.Mensaje));

                return Ok(ApiResponseModel<object>.Ok(resultado.Data, resultado.Mensaje));
            }
            catch (Exception ex)
            {
                return StatusCode(500, ApiResponseModel<object>.Fail(
                    "Error obteniendo estado",
                    new List<string> { ex.Message }
                ));
            }
        }
    }
}
