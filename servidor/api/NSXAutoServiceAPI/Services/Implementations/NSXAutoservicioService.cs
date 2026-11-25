using Newtonsoft.Json;
using NSXAutoservice.Core;
using NSXAutoservice.Models;
using NSXAutoservice.Models.Enum;
using NSXAutoservice.Models.Mapper;
using NSXAutoservice.Models.Request;
using NSXAutoservice.Models.Response;
using NSXAutoServiceAPI.ComunicacionSocket;
using NSXAutoServiceAPI.Services.Interfaces;
using System.Diagnostics;
using System.Security.Cryptography;
using static System.Runtime.InteropServices.JavaScript.JSType;

namespace NSXAutoServiceAPI.Services.Implementations
{
    public class NSXAutoservicioService : IAutoservicioService
    {
        private readonly Consultas _consultas;
        static string _terminal = string.Empty;

        public NSXAutoservicioService(Consultas consultas)
        {
            _consultas = consultas;
            _terminal = _consultas.ObtenerRecurso("Terminal", "Dispensador", 1);
        }

        public ResultadoOperacion<int> CrearPreset(PresetRequest preset)
        {
            try
            {
                _consultas.LogInfo($"Preset {JsonConvert.SerializeObject(preset)}");
                int idPreset = ProcesarPreset(preset, out string error);

                if (idPreset == 0)
                {
                    return new ResultadoOperacion<int>
                    {
                        Exitoso = false,
                        Mensaje = "No se pudo programar el preset " + error,
                    };
                }
                try
                {
                    _consultas.InsertarFormasPagoAutoservicio(idPreset, preset);
                }
                catch (Exception ex)
                {
                    TryCancelarPreset(preset);

                    return new ResultadoOperacion<int>
                    {
                        Exitoso = false,
                        Mensaje = "Error al ingresar formas de pago " + ex.Message
                    };
                }
                return new ResultadoOperacion<int>
                {
                    Exitoso = true,
                    Data = idPreset
                };
            }
            catch (Exception ex)
            {
                TryCancelarPreset(preset);

                return new ResultadoOperacion<int>
                {
                    Exitoso = false,
                    Mensaje = ex.Message
                };
            }
        }

        // Preset de un vendedor de paso: P1 con el turno abierto del vendedor; forma de pago despues, por AnclarFormaPago
        public ResultadoOperacion<int> CrearPresetVendedor(PresetVendedorRequest preset)
        {
            try
            {
                _consultas.LogInfo($"Preset vendedor {JsonConvert.SerializeObject(preset)}");

                var vendedor = _consultas.ObtenerVendedorByDocumento(preset.Documento);
                if (vendedor == null)
                {
                    return new ResultadoOperacion<int> { Exitoso = false, Mensaje = "Vendedor no encontrado" };
                }

                if (!vendedor.Activo)
                {
                    return new ResultadoOperacion<int> { Exitoso = false, Mensaje = "El vendedor está inactivo" };
                }

                int idTurno = _consultas.ObtenerIdTurnoAbiertoByIslero(vendedor.IdIslero);
                if (idTurno <= 0)
                {
                    return new ResultadoOperacion<int> { Exitoso = false, Mensaje = "El vendedor no tiene un turno abierto" };
                }

                string comando = $"{preset.Identificador}|{preset.IdPosicion}|P1|{(int)preset.TipoProgramacion}|{preset.NumeroManguera}|{preset.Valor}|{preset.Placa}|{preset.Km}||||{idTurno}";

                int idPreset = EnviarPresetYEsperar(comando, preset.IdPosicion, out string error);
                if (idPreset == 0)
                {
                    return new ResultadoOperacion<int>
                    {
                        Exitoso = false,
                        Mensaje = "No se pudo programar el preset " + error
                    };
                }

                return new ResultadoOperacion<int> { Exitoso = true, Data = idPreset };
            }
            catch (Exception ex)
            {
                return new ResultadoOperacion<int> { Exitoso = false, Mensaje = ex.Message };
            }
        }

        // C1: pide al MUX leer un identificador de cliente y deja la peticion abierta hasta que lo lee (o se agota el tiempo)
        public ResultadoOperacion<object> LeerIdentificador(LeerIdentificadorRequest request)
        {
            try
            {
                if (request.Tipo == 3)
                {
                    return new ResultadoOperacion<object> { Exitoso = false, Mensaje = "La placa no se lee: se envía en AutorizarCliente" };
                }
                if (!_consultas.IdentificadorClienteHabilitado(request.Identificador, request.Tipo))
                {
                    return new ResultadoOperacion<object> { Exitoso = false, Mensaje = "Tipo de identificador no habilitado en este dispositivo" };
                }
                // Tipo del autoservicio -> posicion en IDCliente de NSX: 1 iButton -> 1, 2 Teclado -> 3
                int tipoNsx = request.Tipo == 2 ? 3 : 1;

                int timeout = Math.Min(Math.Max(request.TimeoutSegundos, 1), 120);
                ComunicacionNSX comunicacionNSX = new ComunicacionNSX(_consultas);
                Stopwatch tiempo = Stopwatch.StartNew();
                int modo = 1; // la primera llamada inicia la lectura en el MUX; las siguientes solo consultan

                while (tiempo.Elapsed.TotalSeconds < timeout)
                {
                    string comando = $"{request.Identificador}|{request.IdPosicion}|C1|{tipoNsx}|{modo}";
                    string respuesta = comunicacionNSX.EnviarComando(comando);
                    string[] resArray = respuesta.Split('|');

                    if (resArray[0] == "E")
                    {
                        return new ResultadoOperacion<object>
                        {
                            Exitoso = false,
                            Mensaje = resArray.Length > 2 ? resArray[2] : respuesta
                        };
                    }

                    if (resArray.Length >= 3 && resArray[0] == "C1" && resArray[1] == "1")
                    {
                        return new ResultadoOperacion<object>
                        {
                            Exitoso = true,
                            Data = new { serial = string.Join("|", resArray.Skip(2)) },
                            Mensaje = "Identificador leido"
                        };
                    }

                    if (resArray.Length < 2 || resArray[0] != "C1" || resArray[1] != "PENDIENTE")
                    {
                        return new ResultadoOperacion<object> { Exitoso = false, Mensaje = "Respuesta no esperada de NSX: " + respuesta };
                    }

                    modo = 0;
                    Thread.Sleep(500);
                }

                return new ResultadoOperacion<object> { Exitoso = false, Mensaje = $"No se leyó el identificador en {timeout} segundos" };
            }
            catch (Exception ex)
            {
                return new ResultadoOperacion<object> { Exitoso = false, Mensaje = ex.Message };
            }
        }

        // C2: autoriza a un cliente local con el serial leido; va al turno abierto del vendedor (Documento) o, sin el, al turno abierto de la isla (turno 0)
        public ResultadoOperacion<object> AutorizarCliente(AutorizarClienteRequest request)
        {
            try
            {
                _consultas.LogInfo($"Autorizar cliente posicion {request.IdPosicion} tipo {request.TipoIdentificador} serial {request.Serial}");

                if (!_consultas.IdentificadorClienteHabilitado(request.Identificador, request.TipoIdentificador))
                {
                    return new ResultadoOperacion<object> { Exitoso = false, Mensaje = "Tipo de identificador no habilitado en este dispositivo" };
                }

                // Tipo del autoservicio -> NSX: 1 iButton -> 1; 2 Teclado -> 3 (serial + clave); 3 Placa -> se busca el identificador activo del vehiculo
                string serialNsx = request.Serial;
                int tipoNsx = 1;
                if (request.TipoIdentificador == 2)
                {
                    tipoNsx = 3;
                    if (string.IsNullOrEmpty(request.Clave))
                    {
                        return new ResultadoOperacion<object> { Exitoso = false, Mensaje = "La clave es obligatoria para el teclado" };
                    }
                }
                else if (request.TipoIdentificador == 3)
                {
                    var tramas = _consultas.ObtenerTramasActivasByPlaca(request.Serial);
                    if (tramas.Count == 0)
                    {
                        return new ResultadoOperacion<object> { Exitoso = false, Mensaje = "No hay un identificador activo para esa placa" };
                    }
                    if (tramas.Count > 1)
                    {
                        return new ResultadoOperacion<object> { Exitoso = false, Mensaje = "La placa tiene varios identificadores activos" };
                    }
                    serialNsx = tramas[0];
                }

                int idTurno = 0;
                if (!string.IsNullOrWhiteSpace(request.Documento))
                {
                    var vendedor = _consultas.ObtenerVendedorByDocumento(request.Documento);
                    if (vendedor == null)
                    {
                        return new ResultadoOperacion<object> { Exitoso = false, Mensaje = "Vendedor no encontrado" };
                    }
                    if (!vendedor.Activo)
                    {
                        return new ResultadoOperacion<object> { Exitoso = false, Mensaje = "El vendedor está inactivo" };
                    }

                    idTurno = _consultas.ObtenerIdTurnoAbiertoByIslero(vendedor.IdIslero);
                    if (idTurno <= 0)
                    {
                        return new ResultadoOperacion<object> { Exitoso = false, Mensaje = "El vendedor no tiene un turno abierto" };
                    }
                }

                string comando = $"{request.Identificador}|{request.IdPosicion}|C2|{(int)request.TipoProgramacion}|{request.NumeroManguera}|{request.Valor}||{request.Km}|{serialNsx}|{request.Clave}|{tipoNsx}|0|{idTurno}";// placa vacia: NSX la toma del vehiculo del identificador

                DateTime fechaSolicitud = DateTime.Now.AddSeconds(-1);
                ComunicacionNSX comunicacionNSX = new ComunicacionNSX(_consultas);
                string respuesta = comunicacionNSX.EnviarComando(comando);
                string[] resArray = respuesta.Split('|');

                if (resArray[0] != "C2" || resArray.Length < 3 || resArray[1] != "1")
                {
                    return new ResultadoOperacion<object>
                    {
                        Exitoso = false,
                        Mensaje = resArray[0] == "E" && resArray.Length > 2 ? resArray[2] : respuesta
                    };
                }

                // NSX responde al insertar la programacion; se busca su id para consultar el estado del preset
                int idPreset = 0;
                Stopwatch tiempo = Stopwatch.StartNew();
                while (idPreset == 0 && tiempo.Elapsed.TotalSeconds < 5)
                {
                    idPreset = _consultas.ObtenerUltimaProgramacionByIdPosicion(request.IdPosicion, fechaSolicitud);
                    if (idPreset == 0)
                    {
                        Thread.Sleep(500);
                    }
                }

                return new ResultadoOperacion<object>
                {
                    Exitoso = true,
                    Data = new { idPreset, mensaje = string.Join("|", resArray.Skip(2)) },
                    Mensaje = "Cliente autorizado"
                };
            }
            catch (Exception ex)
            {
                return new ResultadoOperacion<object> { Exitoso = false, Mensaje = ex.Message };
            }
        }

        // Stop (S) con el turno del vendedor: NSX solo cancela un preset de ese turno y no si ya esta surtiendo
        public ResultadoOperacion<object> CancelarPresetVendedor(CancelarPresetVendedorRequest request)
        {
            try
            {
                var vendedor = _consultas.ObtenerVendedorByDocumento(request.Documento);
                if (vendedor == null)
                {
                    return new ResultadoOperacion<object> { Exitoso = false, Mensaje = "Vendedor no encontrado" };
                }

                if (!vendedor.Activo)
                {
                    return new ResultadoOperacion<object> { Exitoso = false, Mensaje = "El vendedor está inactivo" };
                }

                int idTurno = _consultas.ObtenerIdTurnoAbiertoByIslero(vendedor.IdIslero);
                if (idTurno <= 0)
                {
                    return new ResultadoOperacion<object> { Exitoso = false, Mensaje = "El vendedor no tiene un turno abierto" };
                }

                string comando = $"{request.Identificador}|{request.IdPosicion}|S|{idTurno}";

                ComunicacionNSX comunicacionNSX = new ComunicacionNSX(_consultas);
                string respuesta = comunicacionNSX.EnviarComando(comando);
                string[] resArray = respuesta.Split('|');

                if (resArray.Length < 2 || resArray[1] != "1")
                {
                    return new ResultadoOperacion<object>
                    {
                        Exitoso = false,
                        Mensaje = resArray.Length > 2 ? resArray[2] : respuesta
                    };
                }

                return new ResultadoOperacion<object> { Exitoso = true, Mensaje = "Preset cancelado correctamente" };
            }
            catch (Exception ex)
            {
                return new ResultadoOperacion<object> { Exitoso = false, Mensaje = ex.Message };
            }
        }

        private void TryCancelarPreset(PresetRequest preset)
        {
            try
            {
                CancelarPreset(preset);
            }
            catch (Exception ex)
            {
                _consultas.LogInfo($"No se pudo cancelar el preset tras un error previo: {ex.Message}");
            }
        }

        public ResultadoOperacion<object> GenerarFactura(FacturacionRequest request)
        {
            try
            {
                var venta = _consultas.ObtenerVentaById(request.IdVenta);
                if (venta == null)
                {
                    return new ResultadoOperacion<object>
                    {
                        Exitoso = false,
                        Mensaje = $"La venta {request.IdVenta} no esta registrada."
                    };
                }
                var factura = _consultas.ValidarFEByIdVenta(request.IdVenta);

                if (factura != null)
                {
                    return new ResultadoOperacion<object>
                    {
                        Exitoso = false,
                        Data = factura,
                        Mensaje = $"La venta {request.IdVenta} ya cuenta con Factura Electronica."
                    };
                }
                try
                {
                    var docDian = _consultas.ObtenerDocumentoDian(request.TipoDocumento);
                    if (docDian == null)
                    {
                        return new ResultadoOperacion<object>
                        {
                            Exitoso = false,
                            Mensaje = $"El tipo de Documento {request.TipoDocumento} no esta registrada."
                        };
                    }
                    if (_consultas.InsertarVentaFactura(request))
                    {
                        return new ResultadoOperacion<object>
                        {
                            Exitoso = true,
                            Data = factura,
                            Mensaje = $"La venta {request.IdVenta} enviada para Factura Electronica."
                        };
                    }
                    else
                    {
                        return new ResultadoOperacion<object>
                        {
                            Exitoso = false,
                            Mensaje = $"Error al insertar venta {request.IdVenta} para Factura Electronica."
                        };
                    }
                }
                catch (Exception e)
                {
                    return new ResultadoOperacion<object>
                    {
                        Exitoso = false,
                        Mensaje = $"Error al insertar venta {request.IdVenta} para Factura Electronica. {e.Message}"
                    };
                }
            }
            catch (Exception ex)
            {
                return new ResultadoOperacion<object>
                {
                    Exitoso = false,
                    Mensaje = ex.Message
                };
            }
        }

        public ResultadoOperacion<object> ObtenerEstadoPreset(int idPreset)
        {
            try
            {
                var estado = _consultas.ObtenerEstadoPreset(idPreset);

                if (estado == null)
                {
                    return new ResultadoOperacion<object>
                    {
                        Exitoso = false,
                        Mensaje = "Preset no encontrado"
                    };
                }

                if (estado.IdVenta == 0)
                {
                    ComunicacionNSX comunicacionNSX = new ComunicacionNSX(_consultas);
                    string comando = $"{_terminal}|{estado.IdPosicion}|E|";
                    string respuesta = comunicacionNSX.EnviarComando(comando);
                    string[] resArray = respuesta.Split('|');
                    if (estado.Estado == 1)
                    {
                        
                        return new ResultadoOperacion<object>
                        {
                            Exitoso = true,
                            Data = new
                            {
                                estadoPreset = estado.Estado,
                                estadoSurtidor = resArray[0],
                                ventaZero = false,
                                venta = (object)null
                            },
                            Mensaje = "Autorización viva"
                        };
                    }

                    if (estado.Estado == 3)
                    {
                        return new ResultadoOperacion<object>
                        {
                            Exitoso = true,
                            Data = new
                            {
                                estadoPreset = estado.Estado,
                                estadoSurtidor = resArray[0],
                                ventaZero = true,
                                venta = (object)null
                            },
                            Mensaje = "El equipo no realizó venta"
                        };
                    }
                }

                var venta = _consultas.ObtenerVentaById(estado.IdVenta);

                return new ResultadoOperacion<object>
                {
                    Exitoso = true,
                    Data = new
                    {
                        estadoPreset = estado.Estado,
                        estadoSurtidor = "Espera",
                        ventaZero = false,
                        venta = venta
                    },
                    Mensaje = "Venta generada correctamente"
                };
            }
            catch (Exception ex)
            {
                return new ResultadoOperacion<object>
                {
                    Exitoso = false,
                    Mensaje = ex.Message
                };
            }
        }

        public List<PreciosModel> ObtenerPrecios()
        {
            throw new NotImplementedException();
        }

        private int ProcesarPreset(PresetRequest preset, out string error)
        {
            string comando = $"{preset.Identificador}|{preset.IdPosicion}|PAS|{(int)preset.TipoProgramacion}|{preset.NumeroManguera}|{preset.Valor}|{preset.Placa}|{preset.Km}||||{_consultas.ObtenerIdTurnoByIdentificador(preset.Identificador)}";//Turno;

            return EnviarPresetYEsperar(comando, preset.IdPosicion, out error);
        }

        private int EnviarPresetYEsperar(string comando, int idPosicion, out string error)
        {
            error = null;
            int idPreset = 0;
            DateTime fechaSolicitud = DateTime.Now.AddSeconds(-1);

            ComunicacionNSX comunicacionNSX = new ComunicacionNSX(_consultas);
            string respuesta = comunicacionNSX.EnviarComando(comando);
            string[] resArray = respuesta.Split('|');
            if (resArray[0] != "E")
            {
                Stopwatch tiempo = new Stopwatch();
                tiempo.Start();

                bool programado = true;

                do
                {
                    int idProgramacion = _consultas.ObtenerUltimaProgramacionByIdPosicion(idPosicion, fechaSolicitud);
                    Thread.Sleep(500);

                    if (idProgramacion != 0)
                    {
                        programado = false;
                        idPreset = idProgramacion;
                        error = "";
                    }
                    else if (tiempo.Elapsed.TotalSeconds >= 10)
                    {
                        tiempo.Stop();
                        programado = false;
                    }

                } while (programado);
            }
            else
            {
                error = resArray.Length > 2 ? resArray[2] : respuesta;
            }
            return idPreset;
        }

        public bool CancelarPreset(PresetRequest preset)
        {
            Thread.Sleep(1000);
            string comando = @$"{preset.Identificador}|{preset.IdPosicion}|S";

            ComunicacionNSX comunicacionNSX = new ComunicacionNSX(_consultas);
            string respuesta = comunicacionNSX.EnviarComando(comando);
            string[] resArray = respuesta.Split('|');
            if (resArray.Length < 2 || resArray[1] != "1")
            {
                return true;
            }
            return false;
        }

        public ResultadoOperacion<ClienteFEModel> ConsultarClienteFE(string documento)
        {
            try 
            {
                var cliente = _consultas.ConsultarClienteFE(documento);
                if (cliente != null)
                {
                    return new ResultadoOperacion<ClienteFEModel>
                    {
                        Exitoso = true,
                        Data = cliente,
                        Mensaje = "Cliente consultado correctamente"
                    };
                }

                int idPosicion = _consultas.ObtenerIdPosicion();
                if (idPosicion <= 0)
                {
                    return new ResultadoOperacion<ClienteFEModel>
                    {
                        Exitoso = false,
                        Data = null,
                        Mensaje = "No hay posiciones configuradas en el mapeo para consultar el cliente."
                    };
                }

                ComunicacionNSX comunicacionNSX = new ComunicacionNSX(_consultas);
                string comando = $"{_terminal}|{idPosicion}|CFE|{documento}";
                string respuesta = comunicacionNSX.EnviarComando(comando);
                string[] resArray = respuesta.Split('|');

                if (resArray[0] != "F")
                {
                    cliente = _consultas.ConsultarClienteFE(documento);

                    if (cliente != null)
                    {
                        return new ResultadoOperacion<ClienteFEModel>
                        {
                            Exitoso = true,
                            Data = cliente,
                            Mensaje = "Cliente consultado correctamente"
                        };
                    }
                    else
                    {
                        return new ResultadoOperacion<ClienteFEModel>
                        {
                            Exitoso = false,
                            Data = null,
                            Mensaje = "Cliente no encontrado después de sincronizar con NSX"
                        };
                    }
                }
                else
                {
                    string errorNSX = resArray.Length > 2 ? resArray[2] : "Error desconocido de NSX";
                    return new ResultadoOperacion<ClienteFEModel>
                    {
                        Exitoso = false,
                        Data = null,
                        Mensaje = errorNSX
                    };
                }
            }
            catch (Exception ex)
            {
                return new ResultadoOperacion<ClienteFEModel>
                {
                    Exitoso = false,
                    Data = null,
                    Mensaje = ex.Message
                };
            }
        }

        public ResultadoOperacion<object> ImprimirVenta(int idVenta)
        {
            try
            {
                var ventaFactura = _consultas.ValidarFEByIdVenta(idVenta);

                if (ventaFactura == null)
                {
                    return new ResultadoOperacion<object>
                    {
                        Exitoso = false,
                        Mensaje = "Factura Electronica no encontrada."
                    };
                }

                if (ventaFactura.Sincronizado == false)
                {
                    return new ResultadoOperacion<object>
                    {
                        Exitoso = true,
                        Mensaje = "Factura Electronica sin procesar"
                    };
                }

                ComunicacionNSX comunicacionNSX = new ComunicacionNSX(_consultas);
                var venta = _consultas.ObtenerVentaById(idVenta);
                string comando = $"{_terminal}|{venta.IdPosicion}|I2|{idVenta}|{venta.TipoTransaccion}";
                string respuesta = comunicacionNSX.EnviarComando(comando);
                string[] resArray = respuesta.Split('|');
                if (resArray[0] != "E")
                {
                    return new ResultadoOperacion<object>
                    {
                        Exitoso = true,
                        Data = ventaFactura,
                        Mensaje = "Factura Electronica Impresa"
                    };
                }
                else 
                {
                    return new ResultadoOperacion<object>
                    {
                        Exitoso = false,
                        Data = ventaFactura,
                        Mensaje = $"Error al Imprimir {resArray[2]}"
                    };
                }
            }
            catch (Exception ex)
            {
                return new ResultadoOperacion<object>
                {
                    Exitoso = false,
                    Mensaje = ex.Message
                };
            }
        }


        public ResultadoOperacion<VendedorModel> ValidarVendedor(string documento,string password)
        {
            try
            {
                var vendedor = _consultas.ValidarVendedor(documento,password);

                if (vendedor == null)
                {
                    return new ResultadoOperacion<VendedorModel>
                    {
                        Exitoso = false,
                        Data = null,
                        Mensaje = "Credenciales inválidas"
                    };
                }

                if (!vendedor.Activo)
                {
                    return new ResultadoOperacion<VendedorModel>
                    {
                        Exitoso = false,
                        Data = vendedor,
                        Mensaje = "El vendedor está inactivo"
                    };
                }

                // Cualquier vendedor puede apoyar en la cara: si ya tiene turno abierto se devuelve para no pedirlo de nuevo
                vendedor.IdTurnoAbierto = _consultas.ObtenerIdTurnoAbiertoByIslero(vendedor.IdIslero);

                return new ResultadoOperacion<VendedorModel>
                {
                    Exitoso = true,
                    Data = vendedor,
                    Mensaje = "Vendedor validado correctamente"
                };
            }
            catch (Exception ex)
            {
                return new ResultadoOperacion<VendedorModel>
                {
                    Exitoso = false,
                    Data = null,
                    Mensaje = ex.Message
                };
            }
        }

        public ResultadoOperacion<object> AbrirTurno(TurnoRequest request)
        {
            try
            {
                var vendedor = _consultas.ValidarVendedor(
                    request.Documento,
                    request.Password);

                if (vendedor == null)
                {
                    return new ResultadoOperacion<object>
                    {
                        Exitoso = false,
                        Data = null,
                        Mensaje = "Credenciales inválidas"
                    };
                }

                if (!vendedor.Activo)
                {
                    return new ResultadoOperacion<object>
                    {
                        Exitoso = false,
                        Data = null,
                        Mensaje = "El vendedor está inactivo"
                    };
                }

                // Validar turno abierto
                //bool existeTurno =
                //    _consultas.ExisteTurnoAbierto(
                //        request.IdPosicion);

                //if (existeTurno)
                //{
                //    return new ResultadoOperacion<object>
                //    {
                //        Exitoso = false,
                //        Data = null,
                //        Mensaje = "La posición ya tiene un turno abierto"
                //    };
                //}

                // Abrir turno
                string error;

                int idTurno = AbrirTurno(request, vendedor.IdIslero, out error);

                if (idTurno <= 0)
                {
                    return new ResultadoOperacion<object>
                    {
                        Exitoso = false,
                        Data = null,
                        Mensaje = error ?? "No fue posible abrir el turno"
                    };
                }

                return new ResultadoOperacion<object>
                {
                    Exitoso = true,
                    Data = new
                    {
                        IdTurno = idTurno,
                        Posicion = request.IdPosicion,
                        Vendedor =
                            $"{vendedor.Nombre} {vendedor.Apellidos}"
                    },
                    Mensaje = "Turno abierto correctamente"
                };
            }
            catch (Exception ex)
            {
                return new ResultadoOperacion<object>
                {
                    Exitoso = false,
                    Data = null,
                    Mensaje = ex.Message
                };
            }
        }

        public ResultadoOperacion<object> CerrarTurno(TurnoRequest request)
        {
            try
            {
                var vendedor = _consultas.ValidarVendedor(request.Documento, request.Password);

                if (vendedor == null)
                {
                    return new ResultadoOperacion<object>
                    {
                        Exitoso = false,
                        Data = null,
                        Mensaje = "Credenciales inválidas"
                    };
                }

                if (!vendedor.Activo)
                {
                    return new ResultadoOperacion<object>
                    {
                        Exitoso = false,
                        Data = null,
                        Mensaje = "El vendedor está inactivo"
                    };
                }

                //bool existeturno =
                //    _consultas.(
                //        request.idposicion);

                //if (!existeturno)
                //{
                //    return new ResultadoOperacion<object>
                //    {
                //        exitoso = false,
                //        data = null,
                //        mensaje = "la posición no tiene un turno abierto"
                //    };
                //}

                string error;

                bool cerrado = CerrarTurno(
                    request,
                    out error);

                if (!cerrado)
                {
                    return new ResultadoOperacion<object>
                    {
                        Exitoso = false,
                        Data = null,
                        Mensaje = error ?? "No fue posible cerrar el turno"
                    };
                }

                return new ResultadoOperacion<object>
                {
                    Exitoso = true,
                    Data = new
                    {
                        Posicion = request.IdPosicion,
                        Vendedor =
                            $"{vendedor.Nombre} {vendedor.Apellidos}"
                    },
                    Mensaje = "Turno cerrado correctamente"
                };
            }
            catch (Exception ex)
            {
                return new ResultadoOperacion<object>
                {
                    Exitoso = false,
                    Data = null,
                    Mensaje = ex.Message
                };
            }
        }

        private int AbrirTurno(TurnoRequest turno, int idIslero, out string error)
        {
            error = null;
            int idTurno = 0;
            DateTime fechaSolicitud = DateTime.Now.AddSeconds(-1);
            string comando = $"{turno.Identificador}|{turno.IdPosicion}|T1|{turno.Documento}|{turno.Password}";

            ComunicacionNSX comunicacionNSX = new ComunicacionNSX(_consultas);
            string respuesta = comunicacionNSX.EnviarComando(comando);
            string[] resArray = respuesta.Split('|');
            if (resArray[0] != "E")
            {
                Stopwatch tiempo = new Stopwatch();
                tiempo.Start();

                bool programado = true;

                do
                {
                    // El terminal NSX no siempre graba el MacTerminal en Turnos.Turno,
                    // asi que se busca por el vendedor (Islero) en vez del identificador.
                    int idTur = _consultas.ObtenerIdTurnoByDocumento(idIslero);
                    Thread.Sleep(500);

                    if (idTur != 0)
                    {
                        programado = false;
                        idTurno = idTur;
                        error = "";
                    }
                    else if (tiempo.Elapsed.TotalSeconds >= 10)
                    {
                        tiempo.Stop();
                        programado = false;
                    }

                } while (programado);
            }
            else
            {
                error = resArray.Length > 2 ? resArray[2] : respuesta;
            }
            return idTurno;
        }

        private bool CerrarTurno(TurnoRequest turno, out string error)
        {
            error = null;

            string comando = $"{turno.Identificador}|{turno.IdPosicion}|T2|{turno.Documento}|{turno.Password}";

            ComunicacionNSX comunicacionNSX = new ComunicacionNSX(_consultas);

            string respuesta = comunicacionNSX.EnviarComando(comando);

            if (string.IsNullOrWhiteSpace(respuesta))
            {
                error = "Sin respuesta de NSX";
                return false;
            }

            string[] resArray = respuesta.Split('|');

            // E = Error
            if (resArray[0] == "E")
            {
                error = resArray.Length > 2
                    ? resArray[2]
                    : "Error desconocido cerrando turno";

                return false;
            }

            return true;

        }

        public ResultadoOperacion<object> ValidarClienteFidelidad(FidelidadConsultarRequest request)
        {
            try
            {
                int posicion = _consultas.ObtenerIdsPosicionByIdentificador(request.Identificador).FirstOrDefault();
                if (posicion <= 0)
                    posicion = _consultas.ObtenerIdPosicionByIdentificador(request.Identificador);

                if (posicion <= 0)
                {
                    return new ResultadoOperacion<object>
                    {
                        Exitoso = false,
                        Mensaje = "No se puede obtener la posicion por el identificador."
                    };
                }

                var comando = ArmarComando(request, posicion);
                if (comando == null)
                {
                    return new ResultadoOperacion<object>
                    {
                        Exitoso = false,
                        Mensaje = "Error al identificar fidelidad."
                    };
                }
                ComunicacionNSX comunicacionNSX = new ComunicacionNSX(_consultas);
                string respuesta = comunicacionNSX.EnviarComando(comando);
                string[] resArray = respuesta.Split('|');

                return ParsearRespuesta(respuesta, request.IdTipoFidelidad);
            }
            catch (Exception ex)
            {
                return new ResultadoOperacion<object>
                {
                    Exitoso = false,
                    Mensaje = ex.Message
                };
            }
        }

        private string ArmarComando(FidelidadConsultarRequest request, int idPosicion)
        {
            // Igual que NSX2: F1|tipoDocumento|documento|nombre del programa (la app manda codigo DIAN; Commodo siempre 7, celular)
            string sistema = NombreSistemaFidelidad(request.IdTipoFidelidad);
            int tipoDocumento = FidelidadDocumentoMapper.ObtenerTipoDocumentoNsx(request.IdTipoFidelidad, request.TipoDocumento);

            return $"{request.Identificador}|{idPosicion}|F1|{tipoDocumento}|{request.Documento}|{sistema}";
        }

        // El id del programa es de la Orange Pi/API; NSX2 y Prime reciben el nombre. Solo LifeMiles y Commodo.
        private static string NombreSistemaFidelidad(TipoFidelidadEnum tipoFidelidad)
        {
            return tipoFidelidad switch
            {
                TipoFidelidadEnum.LifeMiles => "LifeMiles",
                TipoFidelidadEnum.Commodo => "Commodo",
                _ => throw new ArgumentException("Programa de fidelidad no soportado")
            };
        }

        private ResultadoOperacion<object> ParsearRespuesta(string respuesta, TipoFidelidadEnum tipoFidelidad)
        {
            try
            {
                return ParsearRespuestaFidelidad(respuesta, "F1", tipoFidelidad);
            }
            catch (Exception ex)
            {
                return new ResultadoOperacion<object>
                {
                    Exitoso = false,
                    Mensaje = $"Error al parsear respuesta: {ex.Message}"
                };
            }
        }

        // Respuesta de F1/F2: "<F1|F2>|1|mensaje" ok, "<F1|F2>|0|mensaje" error (igual en NSX2 y Prime).
        private ResultadoOperacion<object> ParsearRespuestaFidelidad(string respuesta, string comando, TipoFidelidadEnum tipoFidelidad, string? nombreConocido = null, decimal? saldoFinal = null, string? acumuladoCalculado = null)
        {
            if (string.IsNullOrWhiteSpace(respuesta))
            {
                return new ResultadoOperacion<object> { Exitoso = false, Mensaje = "Sin respuesta de NSX" };
            }

            var partes = respuesta.Split('|');
            string mensaje = partes.Length > 2 ? partes[2].Trim() : (partes.Length > 1 ? partes[1].Trim() : respuesta);

            if (partes.Length < 3 || !partes[0].Trim().Equals(comando, StringComparison.OrdinalIgnoreCase) || partes[1].Trim() != "1")
            {
                return new ResultadoOperacion<object>
                {
                    Exitoso = false,
                    Mensaje = string.IsNullOrEmpty(mensaje) ? "No se pudo completar la operacion de fidelidad" : mensaje
                };
            }

            // Nombre del cliente y millas ganadas salen del texto de NSX: "<cliente> Balance: <n>" (F1) o "<cliente> Acumulacion Millas: <n> millas" (F2)
            string nombreCliente = mensaje;
            string? acumulado = null;
            decimal? saldo = null;
            var balance = System.Text.RegularExpressions.Regex.Match(mensaje, @"^(.*?)\s*Balance:\s*(.+)$");
            var acumulacion = System.Text.RegularExpressions.Regex.Match(mensaje, @"^(.*?)\s*Acumulacion Millas:\s*(\d+)");
            if (balance.Success)
            {
                nombreCliente = balance.Groups[1].Value.Trim();
                saldo = ParsearDecimalFidelidad(balance.Groups[2].Value);
            }
            else if (acumulacion.Success)
            {
                nombreCliente = acumulacion.Groups[1].Value.Trim();
                acumulado = acumulacion.Groups[2].Value.Trim();
            }
            else if (comando == "F2" && !string.IsNullOrWhiteSpace(nombreConocido))
            {
                // Commodo solo responde "Transaccion Exitosa": se devuelve el nombre que mando la app
                nombreCliente = nombreConocido.Trim();
            }

            // Consulta (F1): programa, nombre y saldo del cliente (null si el programa no lo informa)
            if (comando == "F1")
            {
                return new ResultadoOperacion<object>
                {
                    Exitoso = true,
                    Data = new { IdFidelidad = (int)tipoFidelidad, Programa = NombreSistemaFidelidad(tipoFidelidad), Nombre = nombreCliente, Saldo = saldo },
                    Mensaje = nombreCliente
                };
            }

            return new ResultadoOperacion<object>
            {
                Exitoso = true,
                Data = new
                {
                    IdFidelidad = (int)tipoFidelidad,
                    Programa = NombreSistemaFidelidad(tipoFidelidad),
                    Nombre = nombreCliente,
                    Acumulado = acumulado ?? acumuladoCalculado,
                    Saldo = saldoFinal,
                    Mensaje = mensaje
                },
                Mensaje = mensaje
            };
        }

        private static decimal? ParsearDecimalFidelidad(string texto)
        {
            // NSX arma el texto con la cultura del equipo (coma decimal, sin separador de miles)
            return decimal.TryParse(texto.Trim().Replace(',', '.'), System.Globalization.NumberStyles.Float, System.Globalization.CultureInfo.InvariantCulture, out var valor)
                ? valor
                : null;
        }

        // Saldo actual del cliente en el programa (F1). null si no responde o el programa no lo informa.
        private decimal? ConsultarSaldoFidelidad(FidelidadAcumularRequest request, int posicion)
        {
            try
            {
                string sistema = NombreSistemaFidelidad(request.IdTipoFidelidad);
                int tipoDocumento = FidelidadDocumentoMapper.ObtenerTipoDocumentoNsx(request.IdTipoFidelidad, request.TipoDocumento);
                var comando = $"{request.Identificador}|{posicion}|F1|{tipoDocumento}|{request.Documento}|{sistema}";

                var partes = new ComunicacionNSX(_consultas).EnviarComando(comando).Split('|');
                if (partes.Length < 3 || partes[1].Trim() != "1")
                {
                    return null;
                }

                var balance = System.Text.RegularExpressions.Regex.Match(partes[2], @"Balance:\s*(.+)$");
                return balance.Success ? ParsearDecimalFidelidad(balance.Groups[1].Value) : null;
            }
            catch (Exception ex)
            {
                _consultas.LogInfo($"No se pudo consultar el saldo de fidelidad: {ex.Message}");
                return null;
            }
        }

        private ResultadoOperacion<object> ParsearPuntosColombia(string respuesta)
        {
            var partes = respuesta.Split('|');

            if (partes[0] != "OK")
            {
                return new ResultadoOperacion<object>
                {
                    Exitoso = false,
                    Mensaje = partes.Length > 1 ? partes[1] : "Error en respuesta"
                };
            }

            var cliente = new
            {
                Nombre = partes.Length > 1 ? partes[1].ToUpperInvariant() : "",
                Puntos = partes.Length > 3 ? partes[3] : "",
                Saldo = partes.Length > 4 ? partes[4] : ""
            };

            return new ResultadoOperacion<object>
            {
                Exitoso = true,
                Data = cliente,
                Mensaje = "Cliente validado"
            };
        }

        private ResultadoOperacion<object> ParsearViveTerpel(string respuesta)
        {
            var partes = respuesta.Split('|');

            if (partes[0] != "SUCCESS")
            {
                return new ResultadoOperacion<object>
                {
                    Exitoso = false,
                    Mensaje = partes.Length > 1 ? partes[1] : "Error en respuesta"
                };
            }

            var cliente = new
            {
                ClienteId = partes.Length > 1 ? partes[1] : "",
                Nombre = partes.Length > 2 ? partes[2] : "",
                Saldo = partes.Length > 3 ? ParsearDecimalFidelidad(partes[3]) ?? 0m : 0m
            };

            return new ResultadoOperacion<object>
            {
                Exitoso = true,
                Data = cliente,
                Mensaje = "Cliente validado"
            };
        }

        private ResultadoOperacion<object> ParsearCommodo(string respuesta)
        {
            var partes = respuesta.Split('|');

            if (partes[0] != "OK")
            {
                return new ResultadoOperacion<object>
                {
                    Exitoso = false,
                    Mensaje = partes.Length > 1 ? partes[1] : "Error en respuesta"
                };
            }

            var cliente = new
            {
                ClienteId = partes.Length > 1 ? partes[1] : "",
                Nombre = partes.Length > 2 ? partes[2] : "",
                Saldo = partes.Length > 3 ? ParsearDecimalFidelidad(partes[3]) ?? 0m : 0m
            };

            return new ResultadoOperacion<object>
            {
                Exitoso = true,
                Data = cliente,
                Mensaje = "Cliente validado"
            };
        }

        private ResultadoOperacion<object> ParsearLocal(string respuesta)
        {
            // Adaptar según tu formato local
            var partes = respuesta.Split('|');

            var cliente = new
            {
                ClienteId = partes.Length > 1 ? partes[1] : "",
                Nombre = partes.Length > 2 ? partes[2] : "",
                Saldo = partes.Length > 3 ? ParsearDecimalFidelidad(partes[3]) ?? 0m : 0m
            };

            return new ResultadoOperacion<object>
            {
                Exitoso = true,
                Data = cliente,
                Mensaje = "Cliente validado"
            };
        }

        private ResultadoOperacion<object> ParsearLeal(string respuesta)
        {
            // Adaptar según tu formato Leal
            var partes = respuesta.Split('|');

            var cliente = new
            {
                ClienteId = partes.Length > 1 ? partes[1] : "",
                Nombre = partes.Length > 2 ? partes[2] : "",
                Saldo = partes.Length > 3 ? ParsearDecimalFidelidad(partes[3]) ?? 0m : 0m
            };

            return new ResultadoOperacion<object>
            {
                Exitoso = true,
                Data = cliente,
                Mensaje = "Cliente validado"
            };
        }

        public ResultadoOperacion<object> AcumularFidelidad(FidelidadAcumularRequest request)
        {
            try
            {
                _consultas.LogInfo($"Acumulacion {JsonConvert.SerializeObject(request)}");
                int posicion = _consultas.ObtenerIdPosicionVenta(request.IdVenta);
                if (posicion <= 0)
                    posicion = _consultas.ObtenerIdPosicionByIdentificador(request.Identificador);

                if (posicion <= 0)
                {
                    return new ResultadoOperacion<object>
                    {
                        Exitoso = false,
                        Mensaje = "No se puede obtener la posicion por el identificador."
                    };
                }

                var comando = ArmarComandoAcumular(request, posicion);
                if (comando == null)
                {
                    return new ResultadoOperacion<object>
                    {
                        Exitoso = false,
                        Mensaje = "Error al identificar fidelidad."
                    };
                }

                // Commodo no informa puntos ganados ni saldo al acumular: se consulta el saldo antes y despues
                bool reportaSaldo = request.IdTipoFidelidad == TipoFidelidadEnum.Commodo;
                decimal? saldoAntes = reportaSaldo ? ConsultarSaldoFidelidad(request, posicion) : null;

                ComunicacionNSX comunicacionNSX = new ComunicacionNSX(_consultas);
                string respuesta = comunicacionNSX.EnviarComando(comando,15000);

                var resultado = ParsearRespuestaAcumular(respuesta, request.IdTipoFidelidad, request.NombreCliente);
                if (!reportaSaldo || !resultado.Exitoso)
                {
                    return resultado;
                }

                decimal? saldoDespues = ConsultarSaldoFidelidad(request, posicion);
                string? ganado = saldoAntes.HasValue && saldoDespues.HasValue
                    ? (saldoDespues.Value - saldoAntes.Value).ToString(System.Globalization.CultureInfo.InvariantCulture)
                    : null;

                return ParsearRespuestaAcumular(respuesta, request.IdTipoFidelidad, request.NombreCliente, saldoDespues, ganado);
            }
            catch (Exception ex)
            {
                return new ResultadoOperacion<object>
                {
                    Exitoso = false,
                    Mensaje = ex.Message
                };
            }
        }

        private string ArmarComandoAcumular(FidelidadAcumularRequest request, int idPosicion)
        {
            // Igual que NSX2: F2|tipoDocumento|documento|programa|tipoVenta (2 = venta anterior)|nombre del cliente
            // Campo 9 (extra, NSX2 lo ignora): idVenta a fidelizar; sin el, NSX usa la ultima venta de la posicion.
            string sistema = NombreSistemaFidelidad(request.IdTipoFidelidad);
            int tipoDocumento = FidelidadDocumentoMapper.ObtenerTipoDocumentoNsx(request.IdTipoFidelidad, request.TipoDocumento);

            return $"{request.Identificador}|{idPosicion}|F2|{tipoDocumento}|{request.Documento}|{sistema}|2|{request.NombreCliente}|{request.IdVenta}";
        }

        private ResultadoOperacion<object> ParsearRespuestaAcumular(string respuesta, TipoFidelidadEnum tipoFidelidad, string? nombreCliente = null, decimal? saldoFinal = null, string? acumuladoCalculado = null)
        {
            try
            {
                if (string.IsNullOrWhiteSpace(respuesta))
                {
                    return new ResultadoOperacion<object>
                    {
                        Exitoso = false,
                        Mensaje = "Sin respuesta de NSX"
                    };
                }

                var partes = respuesta.Split('|');
                string marcador = partes[0].Trim();

                // Error de comunicación del socket ("E|0|<mensaje>", "F|...") o rechazo de NSX ("Error|<mensaje>").
                if (marcador.Equals("Error", StringComparison.OrdinalIgnoreCase)
                    || marcador.Equals("E", StringComparison.OrdinalIgnoreCase)
                    || marcador.Equals("F", StringComparison.OrdinalIgnoreCase))
                {
                    string mensajeError = partes.Length > 2 ? partes[2]
                                        : partes.Length > 1 ? partes[1]
                                        : "Error al acumular fidelidad";

                    return new ResultadoOperacion<object>
                    {
                        Exitoso = false,
                        Mensaje = mensajeError
                    };
                }

                return ParsearRespuestaFidelidad(respuesta, "F2", tipoFidelidad, nombreCliente, saldoFinal, acumuladoCalculado);
            }
            catch (Exception ex)
            {
                return new ResultadoOperacion<object>
                {
                    Exitoso = false,
                    Mensaje = $"Error al parsear respuesta: {ex.Message}"
                };
            }
        }

        private ResultadoOperacion<object> ParsearAcumularPuntosColombia(string[] partes)
        {
            // Formato de éxito (NSX):
            // OK|{saldoPuntos}|{puntosAcumulados}|{descripcion}|{nombre}|{documento}|{valorCliente}|${saldoDinero}
            // Ej: OK|205|45|Operacion exitosa|CRISTIAN|1000617592|$960 |$1230
            if (partes[0].Trim() != "OK")
            {
                return new ResultadoOperacion<object>
                {
                    Exitoso = false,
                    Mensaje = partes.Length > 1 ? partes[1].Trim() : "No se pudo acumular la fidelidad"
                };
            }

            string descripcion = partes.Length > 3 ? partes[3].Trim() : "";

            var data = new
            {
                SaldoPuntos = partes.Length > 1 ? partes[1].Trim() : "",
                PuntosAcumulados = partes.Length > 2 ? partes[2].Trim() : "",
                Descripcion = descripcion,
                Nombre = partes.Length > 4 ? partes[4].Trim() : "",
                Documento = partes.Length > 5 ? partes[5].Trim() : "",
                ValorCliente = partes.Length > 6 ? partes[6].Trim() : "",
                SaldoDinero = partes.Length > 7 ? partes[7].Trim() : ""
            };

            return new ResultadoOperacion<object>
            {
                Exitoso = true,
                Data = data,
                Mensaje = descripcion != "" ? descripcion : "Acumulación registrada correctamente"
            };
        }

        private ResultadoOperacion<object> ParsearAcumularGenerico(string[] partes)
        {
            // TODO: adaptar por programa (ViveTerpel, Commodo, Local, Leal) cuando se confirme su formato de respuesta.
            string marcador = partes[0].Trim();
            if (marcador != "OK" && marcador != "SUCCESS")
            {
                return new ResultadoOperacion<object>
                {
                    Exitoso = false,
                    Mensaje = partes.Length > 1 ? partes[1].Trim() : "No se pudo acumular la fidelidad"
                };
            }

            return new ResultadoOperacion<object>
            {
                Exitoso = true,
                Data = new { Detalle = partes.Skip(1).ToArray() },
                Mensaje = "Acumulación registrada correctamente"
            };
        }

        public ResultadoOperacion<object> ObtenerEstado(int idPosicion)
        {
            try
            {
                ComunicacionNSX comunicacionNSX = new ComunicacionNSX(_consultas);
                string comando = $"{_terminal}|{idPosicion}|E|";
                string respuesta = comunicacionNSX.EnviarComando(comando);

                if (string.IsNullOrWhiteSpace(respuesta))
                {
                    return new ResultadoOperacion<object>
                    {
                        Exitoso = false,
                        Mensaje = "Sin respuesta de NSX"
                    };
                }

                string[] resArray = respuesta.Split('|');

                if (resArray[0] == "E")
                {
                    string errorNSX = resArray.Length > 2 ? resArray[2] : "Error desconocido de NSX";
                    return new ResultadoOperacion<object>
                    {
                        Exitoso = false,
                        Mensaje = errorNSX
                    };
                }

                string estadoSurtidor = resArray[0];
                decimal dineroRealTime = resArray.Length > 1 ? ParseDecimal(resArray[1]) : 0;
                decimal volumenRealTime = resArray.Length > 2 ? ParseDecimal(resArray[2]) : 0;
                int gradoRealTime = resArray.Length > 3 ? int.Parse(resArray[3]) : 0;
                int gradoPreset = resArray.Length > 4 && int.TryParse(resArray[4], out int gp) ? gp : 0;

                return new ResultadoOperacion<object>
                {
                    Exitoso = true,
                    Data = new
                    {
                        estadoSurtidor,
                        dinero = dineroRealTime,
                        volumen = volumenRealTime,
                        grado = gradoRealTime,
                        gradoPreset
                    },
                    Mensaje = "Estado consultado correctamente"
                };
            }
            catch (Exception ex)
            {
                return new ResultadoOperacion<object>
                {
                    Exitoso = false,
                    Mensaje = ex.Message
                };
            }
        }

        private static decimal ParseDecimal(string value)
        {
            // Prime envia los decimales con la cultura del equipo (coma en es-*): con Any y cultura invariante "1,25" se leia como 125
            value = value.Replace(',', '.');
            return decimal.TryParse(value, System.Globalization.NumberStyles.Any,
                System.Globalization.CultureInfo.InvariantCulture, out var result) ? result : 0;
        }
    }
}
