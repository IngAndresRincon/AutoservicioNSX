using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity.Data;
using Microsoft.AspNetCore.Mvc;
using NSXAutoservice.Core;
using NSXAutoservice.Models;
using NSXAutoservice.Models.Request;
using NSXAutoservice.Models.Response;

namespace NSXAutoServiceAPI.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class AdminController : Controller
    {
        private readonly Consultas _consultas;
        private readonly ILogger<AdminController> _logger;

        public AdminController(Consultas consultas, ILogger<AdminController> logger)
        {
            _consultas = consultas;
            _logger = logger;
        }

        [HttpPost("GuardarConfiguracionGeneral")]
        public IActionResult GuardarConfiguracionGeneral([FromBody] ConfiguracionGeneralRequest request)
        {
            if (request == null || string.IsNullOrWhiteSpace(request.Nombre))
            {
                return BadRequest(ApiResponseModel<object>.Fail("Nombre de configuracion requerido"));
            }

            try
            {
                _consultas.GuardarConfiguracion(request.Nombre, request.Valor ?? "");
                return Ok(ApiResponseModel<object>.Ok(null, $"Configuracion '{request.Nombre}' guardada correctamente"));
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error guardando configuracion general {Nombre}", request.Nombre);
                return StatusCode(500, ApiResponseModel<object>.Fail(
                    "Error guardando configuracion",
                    new List<string> { ex.Message }
                ));
            }
        }

        [HttpPost("GuardarConfiguracionEstacion")]
        public IActionResult GuardarConfiguraciones([FromBody] ConfiguracionAutoservicioRequest request)
        {
            if (request == null)
            {
                return BadRequest(ApiResponseModel<object>.Ok(null, "Configuraciones requeridas"));
            }

            if (!ModelState.IsValid)
            {
                var errores = ModelState.Values
                    .SelectMany(v => v.Errors)
                    .Select(e => e.ErrorMessage)
                    .ToList();
                return BadRequest(ApiResponseModel<object>.Fail("Datos inválidos", errores));
            }

            try
            {
                _consultas.GuardarConfiguracionesAutoservice(request);
                return Ok(ApiResponseModel<object>.Ok(null, "Configuraciones guardadas correctamente"));
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error guardando configuraciones");
                return StatusCode(500, ApiResponseModel<object>.Fail(
                    "Error guardando configuraciones",
                    new List<string> { ex.Message }
                ));
            }
        }

        [HttpPost("GuardarMarcaciones")]
        public IActionResult GuardarMarcaciones([FromBody] MarcacionesRequest request)
        {
            if (request?.Marcaciones == null)
            {
                return BadRequest(ApiResponseModel<object>.Ok(null, "Marcaciones requeridas"));
            }

            try
            {
                _consultas.GuardarMarcacionesRapidas(request.Marcaciones);

                return Ok(ApiResponseModel<object>.Ok(null, "Marcaciones guardadas correctamente"));
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error guardando marcaciones");
                return StatusCode(500, ApiResponseModel<object>.Fail(
                    "Error guardando marcaciones",
                    new List<string> { ex.Message }
                ));
            }
        }

        [HttpPost("GuardarManguera")]
        public IActionResult GuardarManguera([FromBody] List<MangueraItem> mangueras)
        {
            if (mangueras == null || !mangueras.Any())
            {
                return BadRequest(ApiResponseModel<object>.Ok(null, "Lista vacía"));
            }

            try
            {
                _consultas.GuardarMangueras(mangueras);

                return Ok(ApiResponseModel<object>.Ok(null, "Mangueras guardadas correctamente"));
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error guardando mangueras");
                return StatusCode(500, ApiResponseModel<object>.Fail(
                    "Error guardando mangueras",
                    new List<string> { ex.Message }
                ));
            }
        }

        [HttpPost("GuardarColores")]
        public IActionResult GuardarColores([FromBody] List<string> colores)
        {
            if (colores == null || !colores.Any())
            {
                return BadRequest(ApiResponseModel<object>.Ok(null, "Lista vacía"));
            }

            try
            {
                _consultas.GuardarColores(colores);

                return Ok(ApiResponseModel<object>.Ok(
                    null,
                    "Colores guardados correctamente"
                ));
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error guardando colores");
                return StatusCode(500, ApiResponseModel<object>.Fail(
                    "Error guardando colores",
                    new List<string> { ex.Message }
                ));
            }
        }

        [HttpPost("GuardarMaximosPreset")]
        public IActionResult GuardarMaximosPreset([FromBody] MaximosPresetRequest request)
        {
            if (request?.Productos == null || !request.Productos.Any())
            {
                return BadRequest(ApiResponseModel<object>.Ok(null, "Lista vacía"));
            }
            if (request.Productos.Any(p => p.IdProducto <= 0))
            {
                return BadRequest(ApiResponseModel<object>.Ok(null, "Producto inválido"));
            }


            try
            {
                _consultas.GuardarMaximosPreset(request.Productos);

                return Ok(ApiResponseModel<object>.Ok(null, "Maximos guardados correctamente"));
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error guardando maximos");
                return StatusCode(500, ApiResponseModel<object>.Fail(
                    "Error guardando maximos",
                    new List<string> { ex.Message }
                ));
            }
        }

        [HttpPost("GuardarPantallas")]
        public IActionResult GuardarPantallas([FromBody] List<PantallaRequest> pantallas)
        {
            if (pantallas == null || !pantallas.Any())
            {
                return BadRequest(ApiResponseModel<object>.Ok(null, "Lista vacía"));
            }

            try
            {
                _consultas.GuardarPantallas(pantallas);

                return Ok(ApiResponseModel<object>.Ok(null, "Pantallas guardadas correctamente"));
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error guardando pantallas");
                return StatusCode(500, ApiResponseModel<object>.Fail(
                    "Error guardando pantallas",
                    new List<string> { ex.Message }
                ));
            }
        }

        [HttpPost("GuardarDispositivos")]
        public IActionResult GuardarDispositivos([FromBody] List<DispositivoModel> dispositivos)
        {
            if (dispositivos == null || !dispositivos.Any())
            {
                return BadRequest(ApiResponseModel<object>.Ok(null, "Lista vacía"));
            }

            if (dispositivos.Any(d => d.IdDispensador <= 0))
            {
                return BadRequest(ApiResponseModel<object>.Ok(null, "Dispensador inválido"));
            }

            try
            {
                _consultas.GuardarDispositivos(dispositivos);

                return Ok(ApiResponseModel<object>.Ok(null, "Dispositivos guardados correctamente"));
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error guardando dispositivos. Payload: {@Dispositivos}", dispositivos);
                return StatusCode(500, ApiResponseModel<object>.Fail(
                    "Error guardando dispositivos",
                    new List<string> { ex.Message }
                ));
            }
        }

        [HttpGet("ObtenerFidelidad")]
        public IActionResult ObtenerFidelidad()
        {
            try
            {
                var data = _consultas.ObtenerFidelidadConfiguracion();
                return Ok(ApiResponseModel<object>.Ok(data, "Programas de fidelidad obtenidos correctamente"));
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error obteniendo programas de fidelidad");
                return StatusCode(500, ApiResponseModel<object>.Fail(
                    "Error obteniendo programas de fidelidad",
                    new List<string> { ex.Message }
                ));
            }
        }

        [HttpPost("GuardarFidelidad")]
        public IActionResult GuardarFidelidad([FromBody] List<FidelidadConfigModel> programas)
        {
            if (programas == null || !programas.Any())
            {
                return BadRequest(ApiResponseModel<object>.Fail("Lista vacía", null));
            }

            try
            {
                _consultas.GuardarFidelidadConfiguracion(programas);
                return Ok(ApiResponseModel<object>.Ok(null, "Programas de fidelidad guardados correctamente"));
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error guardando programas de fidelidad. Payload: {@Programas}", programas);
                return StatusCode(500, ApiResponseModel<object>.Fail(
                    "Error guardando programas de fidelidad",
                    new List<string> { ex.Message }
                ));
            }
        }

        [HttpPost("Login")]
        public IActionResult Login(LoginEDSRequest request)
        {
            try
            {
                var usuario = _consultas.ValidarLogin(request.UserName, request.Password);

                if (usuario == null)
                    return Unauthorized(ApiResponseModel<object>.Fail(
                        "Credenciales inválidas",
                        null
                    ));

                return Ok(ApiResponseModel<object>.Ok(usuario, "Login correcto"));
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error en login");
                return StatusCode(500, ApiResponseModel<object>.Fail(
                    "Error en login",
                    new List<string> { ex.Message }
                ));
            }
        }

        [HttpGet("ObtenerDispositivos")]
        public IActionResult ObtenerDispositivos()
        {
            var errores = new List<string>();
            try
            {
                var data = _consultas.ObtenerDispositivos();
                return Ok(ApiResponseModel<object>.Ok(data, "Mapeo obtenido correctamente"));
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error obteniendo mapeo");
                return StatusCode(500, ApiResponseModel<object>.Fail(
                    "Error obteniendo mapeo",
                    new List<string> { ex.Message }
                ));
            }
        }

        [HttpGet("ObtenerDispensadores")]
        public IActionResult ObtenerDispensadores()
        {
            var errores = new List<string>();
            try
            {
                var data = _consultas.ObtenerDispensadoresEDS();
                return Ok(ApiResponseModel<object>.Ok(data, "Dispensadores obtenidos correctamente"));
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error obteniendo dispensadores");
                return StatusCode(500, ApiResponseModel<object>.Fail(
                    "Error obteniendo dispensadores",
                    new List<string> { ex.Message }
                ));
            }
        }

        [HttpGet("ObtenerManguerasDispensador")]
        public IActionResult ObtenerManguerasDispensador(int IdDispensador)
        {
            var errores = new List<string>();
            try
            {
                var data = _consultas.ObtenerDispensadoresEDS();
                return Ok(ApiResponseModel<object>.Ok(data, "Dispensadores obtenidos correctamente"));
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error obteniendo dispensadores");
                return StatusCode(500, ApiResponseModel<object>.Fail(
                    "Error obteniendo dispensadores",
                    new List<string> { ex.Message }
                ));
            }
        }

        [HttpGet("ObtenerMapeoConfiguracion")]
        public IActionResult ObtenerMapeoConfiguracion()
        {
            var errores = new List<string>();
            try
            {
                var data = _consultas.ObtenerMapeo();
                return Ok(ApiResponseModel<object>.Ok(data, "Mapeo obtenido correctamente"));
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error obteniendo mapeo");
                return StatusCode(500, ApiResponseModel<object>.Fail(
                    "Error obteniendo mapeo",
                    new List<string> { ex.Message }
                ));
            }
        }

        [HttpGet("ObtenerCatalogos")]
        public IActionResult ObtenerCatalogos()
        {
            try
            {
                var data = _consultas.ObtenerCatalogos();

                return Ok(ApiResponseModel<object>.Ok(
                    data,
                    "Catálogos obtenidos correctamente"
                ));
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error obteniendo catalogos");
                return StatusCode(500, ApiResponseModel<object>.Fail(
                    "Error obteniendo catálogos",
                    new List<string> { ex.Message }
                ));
            }
        }
        [HttpPost("ConfigurarFormaPago")]
        public IActionResult ConfigurarFormaPago([FromBody] List<FormaPagoAutoRequest> request)
        {
            try
            {
                _consultas.GuardarFormasPago(request);
                return Ok(new { success = true, message = "Formas de pago configuradas correctamente" });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error configurando forma de pago");
                return BadRequest(new { success = false, message = ex.Message });
            }
        }

        // Formas de pago que el vendedor puede anclar a su venta (independiente de las casillas del cliente)
        [HttpGet("ObtenerFormasPagoVendedor")]
        public IActionResult ObtenerFormasPagoVendedor()
        {
            try
            {
                return Ok(ApiResponseModel<object>.Ok(_consultas.ObtenerFormasDePagoVendedorAdmin(), "Formas de pago del vendedor obtenidas correctamente"));
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error obteniendo formas de pago del vendedor");
                return StatusCode(500, ApiResponseModel<object>.Fail("Error obteniendo formas de pago del vendedor", new List<string> { ex.Message }));
            }
        }

        [HttpPost("ConfigurarFormasPagoVendedor")]
        public IActionResult ConfigurarFormasPagoVendedor([FromBody] List<FormaPagoVendedorRequest> request)
        {
            try
            {
                _consultas.GuardarFormasPagoVendedor(request);
                return Ok(new { success = true, message = "Formas de pago del vendedor configuradas correctamente" });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error configurando formas de pago del vendedor");
                return BadRequest(new { success = false, message = ex.Message });
            }
        }

        [HttpPost("GuardarTurnos")]
        public IActionResult GuardarTurnos(List<TurnoItemModel> turnos)
        {
            if (turnos == null || !turnos.Any())
            {
                return BadRequest(
                    ApiResponseModel<object>.Fail(
                        "Lista vacía"
                    )
                );
            }

            bool guardado = _consultas.GuardarTurnos(turnos);

            if (!guardado)
            {
                return StatusCode(500,
                    ApiResponseModel<object>.Fail(
                        "Error guardando turnos"
                    )
                );
            }

            return Ok(
                ApiResponseModel<object>.Ok(
                    null,
                    "Turnos guardados correctamente"
                )
            );
        }
    }
}
