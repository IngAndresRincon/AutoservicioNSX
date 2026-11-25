using Microsoft.AspNetCore.Mvc;
using Newtonsoft.Json;
using NSXAutoservice.Core;
using NSXAutoservice.Models;
using NSXAutoservice.Models.Request;
using NSXAutoservice.Models.Response;


namespace NSXAutoServiceAPI.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class VueltosController : ControllerBase
    {
        private readonly Consultas _consultas;

        public VueltosController(Consultas consultas)
        {
            _consultas = consultas;
        }

        [HttpGet("ConsultarVueltos")]
        public IActionResult ConsultarVueltos(string codigo)
        {
            var errores = new List<string>();
            if (string.IsNullOrEmpty(codigo))
            {
                return BadRequest(ApiResponseModel<object>.Ok(null, "codigo no peude ser null"));
            }
            try
            {
                var data = _consultas.ObtenerEstadoVueltos(codigo);

                if (data == null)
                {
                    return BadRequest(ApiResponseModel<object>.Fail("codigo inválido"));
                }
                string mensaje = "";
                switch (data.IdEstadoVuelto)
                {
                    case 1: // Creado
                        mensaje = "Código válido";
                        break;

                    case 2: // Reservado
                        mensaje = "Código actualmente reservado";
                        break;

                    case 3: // Usado
                        mensaje = $"Código ya fue usado el {data.FechaUso}";
                        break;

                    case 4: // Vencido
                        mensaje = "Código vencido";
                        break;

                    default:
                        mensaje = "Estado desconocido";
                        break;
                }
                var response = new
                {
                    data.Codigo,
                    data.Valor,
                    data.IdEstadoVuelto,
                };

                return Ok(ApiResponseModel<object>.Ok(response, mensaje));
            }
            catch (Exception ex)
            {
                return StatusCode(500, ApiResponseModel<object>.Fail(
                    "Error obteniendo estadovuelto",
                    new List<string> { ex.Message }
                ));
            }
        }

        [HttpPost("GenerarVuelto")]
        public IActionResult GenerarVuelto(VueltoRequest vuelto)
        {
            var errores = new List<string>();

            try
            {
                _consultas.LogInfo($"Vuelto {JsonConvert.SerializeObject(vuelto)}");
                if (vuelto == null)
                    return BadRequest(ApiResponseModel<object>.Fail("El cuerpo de la solicitud no puede ser nulo"));

                if (vuelto.IdPreset <= 0)
                    return BadRequest(ApiResponseModel<object>.Fail("IdPreset inválido", new List<string> { "IdPreset debe ser mayor a 0" }));
                DispPosProgramacionModel dispPosProgramacion = new DispPosProgramacionModel();
                dispPosProgramacion = _consultas.ObtenerDispPosProgramacion(vuelto.IdPreset);
                if (dispPosProgramacion == null)
                    return BadRequest(ApiResponseModel<object>.Fail("IdPreset No encontrado", new List<string> { "IdPreset no fue encontrado en eel sistema" }));


                AutoservicioVueltosModel vueltosModel = new AutoservicioVueltosModel();
                vueltosModel = _consultas.ObtenerVueltoByIdPreset(vuelto.IdPreset);

                if (vueltosModel != null)
                    return BadRequest(ApiResponseModel<object>.Ok(
                        new { Codigo = vueltosModel.Codigo },
                        $"La Programacion {vuelto.IdPreset} ya tiene un vuelto asociado"
                    ));

                if (vuelto.Valor <= 0)
                    return BadRequest(ApiResponseModel<object>.Fail("Valor inválido", new List<string> { "El valor debe ser mayor a 0" }));

                if (vuelto.IdFormaPago <= 0)
                    return BadRequest(ApiResponseModel<object>.Fail("IdFormaPago inválido", new List<string> { "IdFormaPago debe ser mayor a 0" }));

                var codigo = _consultas.GenerarVuelto(vuelto.IdPreset, vuelto.Valor, vuelto.IdFormaPago);

                if (string.IsNullOrEmpty(codigo))
                    return BadRequest(ApiResponseModel<object>.Fail("No fue posible generar el vuelto"));
                _consultas.LogInfo($"REspuesta  {JsonConvert.SerializeObject(codigo)}");
                return Ok(ApiResponseModel<object>.Ok(new { Codigo = codigo }, "Vuelto generado correctamente"));
            }
            catch (Exception ex)
            {
                return StatusCode(500, ApiResponseModel<object>.Fail(
                    "Error generando vuelto",
                    new List<string> { ex.Message }
                ));
            }
        }

        [HttpPost("RegistrarVuelto")]
        public IActionResult RegistrarVuelto(RegistrarVueltoRequest request)
        {
            try
            {
                if (request == null)
                    return BadRequest(ApiResponseModel<object>.Fail("El cuerpo de la solicitud no puede ser nulo"));

                if (string.IsNullOrEmpty(request.Codigo))
                    return BadRequest(ApiResponseModel<object>.Fail("El código no puede ser nulo o vacío"));

                if (request.Valor <= 0)
                    return BadRequest(ApiResponseModel<object>.Fail("El valor debe ser mayor a 0"));

                if (request.IdDisPosProgramacion <= 0)
                    return BadRequest(ApiResponseModel<object>.Fail("El valor debe ser mayor a 0"));

                AutoservicioVueltosModel vueltosModel = new AutoservicioVueltosModel();
                vueltosModel = _consultas.ObtenerVueltoByIdPreset(request.IdDisPosProgramacion);
                if (vueltosModel != null)
                    return BadRequest(ApiResponseModel<object>.Fail($"La Programacion {request.IdDisPosProgramacion} ya tiene un vuelto asociado"));

                if (request.IdFormaPago <= 0)
                    return BadRequest(ApiResponseModel<object>.Fail("IdFormaPago inválido"));

                _consultas.RegistrarVuelto(request);

                return Ok(ApiResponseModel<object>.Ok(new { request.Codigo }, "Vuelto registrado correctamente"));
            }
            catch (Exception ex)
            {
                return StatusCode(500, ApiResponseModel<object>.Fail(
                    "Error registrando vuelto",
                    new List<string> { ex.Message }
                ));
            }
        }

        [HttpGet("ImprimirVueltos")]
        public IActionResult ImprimirVueltos(string codigo)
        {
            var errores = new List<string>();
            if (string.IsNullOrEmpty(codigo))
            {
                return BadRequest(ApiResponseModel<object>.Ok(null, "codigo no peude estar vacio"));
            }
            try
            {
                var data = _consultas.ObtenerEstadoVueltos(codigo);

                if (data == null)
                {
                    return BadRequest(ApiResponseModel<object>.Fail("codigo inválido"));
                }

                var response = new
                {
                    data.Codigo,
                    data.Valor,
                    data.IdEstadoVuelto,
                };

                // Estados que no permiten reimpresión
                switch (data.IdEstadoVuelto)
                {
                    case 3: // Usado
                        return BadRequest(ApiResponseModel<object>.Fail(
                            $"No se puede imprimir: el código ya fue usado el {data.FechaUso}",
                            new List<string> { $"Estado del vuelto: {data.IdEstadoVuelto} (Usado)" }
                        ));

                    case 4: // Vencido
                        return BadRequest(ApiResponseModel<object>.Fail(
                            "No se puede imprimir: el código está vencido",
                            new List<string> { $"Estado del vuelto: {data.IdEstadoVuelto} (Vencido)" }
                        ));
                }

                var prog = _consultas.ObtenerDispPosProgramacion(data.IdDisPosProgramacion);

                _consultas.ImprimirQrVueltos(data, prog);

                return Ok(ApiResponseModel<object>.Ok(response, "Impresión enviada correctamente"));
            }
            catch (Exception ex)
            {
                return StatusCode(500, ApiResponseModel<object>.Fail(
                    "Error imprimiedo vuelto",
                    new List<string> { ex.Message }
                ));
            }
        }

        [HttpGet("ObtenerVueltoByIdProgramacion")]
        public IActionResult ObtenerVueltoByIdProgramacion(int idProgramacion)
        {
            if (idProgramacion <= 0)
            {
                return BadRequest(ApiResponseModel<object>.Fail("idProgramacion inválido"));
            }
            try
            {
                var data = _consultas.ObtenerVueltoByIdPreset(idProgramacion);

                if (data == null)
                {
                    return Ok(ApiResponseModel<object>.Ok(null, $"La programación {idProgramacion} no tiene vuelto asociado"));
                }

                return Ok(ApiResponseModel<object>.Ok(data, "Vuelto obtenido correctamente"));
            }
            catch (Exception ex)
            {
                return StatusCode(500, ApiResponseModel<object>.Fail(
                    "Error obteniendo vuelto por programación",
                    new List<string> { ex.Message }
                ));
            }
        }
    }
}
