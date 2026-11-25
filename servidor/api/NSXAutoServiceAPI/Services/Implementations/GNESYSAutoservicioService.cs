using Newtonsoft.Json;
using NSXAutoservice.Core;
using NSXAutoservice.Models;
using NSXAutoservice.Models.Request;
using NSXAutoservice.Models.Response;
using NSXAutoServiceAPI.ComunicacionSocket;
using NSXAutoServiceAPI.Services.Interfaces;
using System.Diagnostics;
using System.Globalization;

namespace NSXAutoServiceAPI.Services.Implementations
{
    public class GNESYSAutoservicioService : IAutoservicioService
    {
        private readonly Consultas _consultas;

        public GNESYSAutoservicioService(Consultas consultas)
        {
            _consultas = consultas;
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

                string error;

                int idTurno = AbrirTurno(request, out error);

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

        private int AbrirTurno(TurnoRequest turno, out string error)
        {
            error = null;
            int idTurno = 0;
            DateTime fechaSolicitud = DateTime.Now.AddSeconds(-1);

            int idIslero = _consultas.ObtenerVendedorByDocumento(turno.Documento).IdIslero;

            if (idIslero == 0)
            {
                error = "No se obtuvo vendedor";
                return idIslero;
            }

            List<int> pos = _consultas.ObtenerIdsPosicionByIdentificador(turno.Identificador);

            string posiciones = string.Join(",", pos);

            string comando = $"TA|{turno.IdPosicion}|{idIslero}|{posiciones}";

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
                    int idTur = Convert.ToInt32(resArray[1]);
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
                error = resArray[2];
            }
            return idTurno;
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
                    vendedor.IdIslero,
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

        private bool CerrarTurno(TurnoRequest turno, int idIslero, out string error)
        {
            error = null;

            int idTurno = _consultas.ObtenerIdTurnoByDocumento(idIslero);

            string comando = $"CT|{turno.IdPosicion}|{idTurno}";

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

        public ResultadoOperacion<int> CrearPresetVendedor(PresetVendedorRequest preset)
        {
            return new ResultadoOperacion<int>
            {
                Exitoso = false,
                Mensaje = "El preset de vendedor no esta disponible para este sistema"
            };
        }

        public ResultadoOperacion<object> LeerIdentificador(LeerIdentificadorRequest request)
        {
            return new ResultadoOperacion<object>
            {
                Exitoso = false,
                Mensaje = "La lectura de identificadores no esta disponible para este sistema"
            };
        }

        public ResultadoOperacion<object> AutorizarCliente(AutorizarClienteRequest request)
        {
            return new ResultadoOperacion<object>
            {
                Exitoso = false,
                Mensaje = "La autorizacion de clientes no esta disponible para este sistema"
            };
        }

        public ResultadoOperacion<object> CancelarPresetVendedor(CancelarPresetVendedorRequest request)
        {
            return new ResultadoOperacion<object>
            {
                Exitoso = false,
                Mensaje = "El preset de vendedor no esta disponible para este sistema"
            };
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
                    _consultas.InsertarFormasPagoAutoservicioGNE(idPreset, preset);
                }
                catch (Exception ex)
                {
                    CancelarPreset(preset);

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
                CancelarPreset(preset);

                return new ResultadoOperacion<int>
                {
                    Exitoso = false,
                    Mensaje = ex.Message
                };
            }
        }

        private int ProcesarPreset(PresetRequest preset, out string error)
        {
            error = null;
            int idPreset = 0;
            DateTime fechaSolicitud = DateTime.Now.AddSeconds(-1);
            string comando = $"PAS|{preset.IdPosicion}|PAS|{(int)preset.TipoProgramacion}|{preset.NumeroManguera}|{preset.Valor}|{preset.Placa}|{preset.Km}||||{preset.IdTurno}";//Turno;

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
                    int idProgramacion = _consultas.ObtenerUltimaProgramacionByIdPosicion(preset.IdPosicion, fechaSolicitud);
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
                error = resArray[2];
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
            if (resArray[1] != "1")
            {
                return true;
            }
            return false;
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
                var factura = _consultas.ValidarFEByIdVentaGNE(request.IdVenta);

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

                    if (_consultas.InsertarVentaFacturaGNE(request))
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

        public List<PreciosModel> ObtenerPrecios()
        {
            throw new NotImplementedException();
        }

        public ResultadoOperacion<object> ValidarClienteFidelidad(FidelidadConsultarRequest request)
        {
            throw new NotImplementedException();
        }

        public ResultadoOperacion<object> AcumularFidelidad(FidelidadAcumularRequest request)
        {
            throw new NotImplementedException();
        }

        public ResultadoOperacion<VendedorModel> ValidarVendedor(string documento, string password)
        {
            try
            {
                var vendedor = _consultas.ValidarVendedor(documento, password);

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

        bool IAutoservicioService.CancelarPreset(PresetRequest preset)
        {
            throw new NotImplementedException();
        }

        public ResultadoOperacion<ClienteFEModel> ConsultarClienteFE(string documento)
        {
            try
            {
                var cliente = _consultas.ConsultarClienteFEGNE(documento);
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
                        Mensaje = "Cliente no encontrado."
                    };
                }
                //ComunicacionNSX comunicacionNSX = new ComunicacionNSX(_consultas);
                //string comando = $"{_terminal}|1|CFE|{documento}";
                //string respuesta = comunicacionNSX.EnviarComando(comando);
                //string[] resArray = respuesta.Split('|');

                //if (resArray[0] != "F")
                //{
                //    cliente = _consultas.ConsultarClienteFE(documento);

                //    if (cliente != null)
                //    {
                //        return new ResultadoOperacion<ClienteFEModel>
                //        {
                //            Exitoso = true,
                //            Data = cliente,
                //            Mensaje = "Cliente consultado correctamente"
                //        };
                //    }
                //    else
                //    {
                //        return new ResultadoOperacion<ClienteFEModel>
                //        {
                //            Exitoso = false,
                //            Data = null,
                //            Mensaje = "Cliente no encontrado después de sincronizar con NSX"
                //        };
                //    }
                //}
                //else
                //{
                //    string errorNSX = resArray.Length > 2 ? resArray[2] : "Error desconocido de NSX";
                //    return new ResultadoOperacion<ClienteFEModel>
                //    {
                //        Exitoso = false,
                //        Data = null,
                //        Mensaje = errorNSX
                //    };
                //}
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
                var ventaFactura = _consultas.ValidarFEByIdVentaGNE(idVenta);
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

                bool impreso = _consultas.MarcarImpresionPendiente(idVenta);

                return new ResultadoOperacion<object>
                {
                    Exitoso = impreso,
                    Data = ventaFactura,
                    Mensaje = impreso ? "Factura Electronica Impresa" : "Error al Imprimir"
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
                    string comando = $"E|{estado.IdPosicion}";
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

                var venta = _consultas.ObtenerVentaByIdGne(estado.IdVenta);

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

        public ResultadoOperacion<object> ObtenerEstado(int idPosicion)
        {
            try
            {
                ComunicacionNSX comunicacionNSX = new ComunicacionNSX(_consultas);
                string comando = $"E|{idPosicion}";
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

                decimal dineroRealTime = resArray.Length > 1 ? decimal.Parse(resArray[1]) : 0m;
                decimal volumenRealTime = resArray.Length > 2 ? decimal.Parse(resArray[2]) : 0m;
                int gradoRealTime = resArray.Length > 3 ? int.Parse(resArray[3]) : 0;
                int gradoPreset = resArray.Length > 4 ? int.Parse(resArray[4]) : 0;

                return new ResultadoOperacion<object>
                {
                    Exitoso = true,
                    Data = new
                    {
                        estadoSurtidor,
                        dinero = dineroRealTime,
                        volumen = volumenRealTime,
                        grado = gradoRealTime,
                        gradoPreset = gradoPreset
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
            if (string.IsNullOrWhiteSpace(value))
                return 0;

            value = value.Trim();

            // Si viene con coma, la tratamos como separador decimal (formato NSX/es-CO)
            // reemplazando por punto para parsear en invariant culture.
            if (value.Contains(',') && !value.Contains('.'))
            {
                value = value.Replace(',', '.');
            }
            // Si por alguna razón viene con ambos (ej. "1.234,56" formato es completo),
            // quitamos el punto de miles y dejamos la coma como decimal.
            else if (value.Contains(',') && value.Contains('.'))
            {
                value = value.Replace(".", "").Replace(',', '.');
            }

            return decimal.TryParse(value, NumberStyles.Any,
                CultureInfo.InvariantCulture, out var result) ? result : 0;
        }
    }
}
