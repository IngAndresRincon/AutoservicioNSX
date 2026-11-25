using Encripcion.Encrypter;
using Newtonsoft.Json;
using NSXAutoservice.Models;
using NSXAutoservice.Models.Enum;
using NSXAutoservice.Models.Reportes.DashBoard;
using NSXAutoservice.Models.Request;
using System;
using System.Data;
using System.Data.SqlClient;
using System.Globalization;
using System.Text.Json;
using static System.Runtime.InteropServices.JavaScript.JSType;

namespace NSXAutoservice.Core
{
    public class Consultas
    {
        private readonly Conexion _conexion;
        private static char[] _chars;
        private static Random _random;
        private static bool _gne;

        public Consultas(Conexion conexion)
        {
            _conexion = conexion;
            _chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789".ToCharArray();
            _random = new Random();

            string sistema = ObtenerConfiguracionAutoservice("Sistema");
            _gne = sistema.Equals("GNESYS", StringComparison.OrdinalIgnoreCase);
        }

        public MapeoModel ObtenerMapeo(string identificador)
        {
            MapeoModel Mapeo = new MapeoModel();

            Mapeo.Estacion = ObtenerEstacion();
            Mapeo.Dispensadores = ObtenerDispensadoresByIdentificador(identificador);
            Mapeo.FormasPago = ObtenerFormasDePago();
            Mapeo.FormasPagoVendedor = ObtenerFormasDePagoVendedor();
            Mapeo.Fidelidad = ObtenerFidelidad();
            Mapeo.Identificadores = ObtenerIdentificadoresCliente(identificador);

            return Mapeo;
        }

        // Tipos de identificador de cliente del autoservicio, en el orden de las banderas de Dispositivo.IdentificadoresCliente
        private static readonly (int Id, string Nombre)[] TiposIdentificadorCliente =
        {
            (1, "iButton"),
            (2, "Teclado"),
            (3, "Placa")
        };

        // Tipos habilitados del dispositivo (banderas "1|1|1"); si la columna no existe en la base, todos
        public List<IdentificadorClienteModel> ObtenerIdentificadoresCliente(string identificador)
        {
            string banderas = "1|1|1";

            using var conn = _conexion.CrearConexion();
            conn.Open();
            using var cmd = new SqlCommand("SELECT COL_LENGTH('Autoservice.Dispositivo', 'IdentificadoresCliente')", conn);
            object columna = cmd.ExecuteScalar();
            if (columna != null && columna != DBNull.Value)
            {
                cmd.CommandText = "SELECT TOP 1 IdentificadoresCliente FROM Autoservice.Dispositivo WHERE Activo = 1 AND Identificador = @Identificador";
                cmd.Parameters.AddWithValue("@Identificador", identificador ?? "");
                object valor = cmd.ExecuteScalar();
                if (valor != null && valor != DBNull.Value)
                    banderas = valor.ToString();
            }

            string[] activos = banderas.Split('|');
            var lista = new List<IdentificadorClienteModel>();
            for (int i = 0; i < TiposIdentificadorCliente.Length; i++)
            {
                if (i < activos.Length && activos[i].Trim() == "1")
                    lista.Add(new IdentificadorClienteModel { Id = TiposIdentificadorCliente[i].Id, Nombre = TiposIdentificadorCliente[i].Nombre });
            }
            return lista;
        }

        public bool IdentificadorClienteHabilitado(string identificador, int tipo)
        {
            return ObtenerIdentificadoresCliente(identificador).Any(t => t.Id == tipo);
        }

        // Tramas de los identificadores activos de los vehiculos con esa placa
        public List<string> ObtenerTramasActivasByPlaca(string placa)
        {
            var tramas = new List<string>();

            using var conn = _conexion.CrearConexion();
            using var cmd = new SqlCommand(@"SELECT DISTINCT i.Trama
                                             FROM dbo.Vehiculo v
                                             INNER JOIN dbo.IdentificadorVehiculo iv ON iv.Fk_IdVehiculo = v.Pk_IdVehiculo AND iv.Activo = 1
                                             INNER JOIN dbo.Identificador i ON i.Pk_IdIdentificador = iv.Fk_IdIdentificador AND i.Activo = 1
                                             WHERE v.Placa = @Placa", conn);
            cmd.Parameters.AddWithValue("@Placa", (placa ?? "").Trim());

            conn.Open();
            using var dr = cmd.ExecuteReader();
            while (dr.Read())
                tramas.Add((string)dr["Trama"]);

            return tramas;
        }

        public MapeoModel ObtenerMapeo()
        {
            MapeoModel Mapeo = new MapeoModel();

            Mapeo.Estacion = ObtenerEstacion();
            Mapeo.Dispensadores = ObtenerDispensadores();
            Mapeo.FormasPago = ObtenerFormasDePago();
            Mapeo.Fidelidad = ObtenerFidelidad();
            
            return Mapeo;
        }

        public EstacionModel ObtenerEstacion()
        {
            EstacionModel estacion = new EstacionModel();
            string nombre = "NombreEstacion";
            try
            {
                estacion.NombreEDS = ObtenerConfiguracionEstacion(nombre);
                estacion.Bandera = ObtenerBandera();
                estacion.MarcacionesRapidas = ObtenerMarcacionesRapidas();
                estacion.Turnos = ObtenerTurnos();
                estacion.MaximoVueltos =double.TryParse(ObtenerConfiguracionAutoservice("MaxVueltos"), out double valor) ? valor: 0;
            }
            catch (Exception)
            {
                throw;
            }

            return estacion;
        }

        public string ObtenerRecurso(string nombre, string entidad, int identidad)
        {
            string valor = "";

            using var conn = _conexion.CrearConexion();

            using var co = new SqlCommand();
            co.Connection = conn;

            try
            {
                co.CommandText = @$"SELECT Valor FROM [Autoservice].[Recursos]
                                    WHERE Nombre = '{nombre}' AND Entidad = '{entidad}' AND IdEntidad = {identidad}";


                conn.Open();
                using SqlDataReader dr = co.ExecuteReader();

                while (dr.Read())
                {
                    valor = (string)dr["Valor"];
                }
            }
            catch (Exception)
            {
                throw;
            }
            finally
            {
                conn.Close();
            }

            return valor;
        }

        public List<string> ObtenerColoresBandera()
        {
            var colores = new List<string>();

            using var conn = _conexion.CrearConexion();
            using var co = new SqlCommand();

            co.Connection = conn;

            try
            {
                co.CommandText = @"
                                    SELECT Nombre, Valor
                                    FROM [Autoservice].[Recursos]
                                    WHERE Entidad = @Entidad
                                        AND Nombre IN ('Color1', 'Color2', 'Color3')
                                    ORDER BY Nombre";

                co.Parameters.AddWithValue("@Entidad", "Bandera");

                conn.Open();

                using SqlDataReader dr = co.ExecuteReader();

                while (dr.Read())
                {
                    colores.Add(dr["Valor"]?.ToString() ?? "");
                }
            }
            catch
            {
                throw;
            }
            finally
            {
                conn.Close();
            }

            return colores;
        }

        public string ObtenerConfiguracionEstacion(string nombre)
        {
            string valor = "";

            using var conn = _conexion.CrearConexion();

            using var co = new SqlCommand();
            co.Connection = conn;

            try
            {
                co.CommandText = @$"SELECT Valor FROM [dbo].[ConfiguracionEstacion]
                                    WHERE Nombre = '{nombre}'";


                conn.Open();
                using SqlDataReader dr = co.ExecuteReader();

                while (dr.Read())
                {
                    valor = (string)dr["Valor"];
                }
            }
            catch (Exception)
            {
                throw;
            }
            finally
            {
                conn.Close();
            }

            return valor;
        }

        public string ObtenerConfiguracion(string nombre)
        {
            string valor = "";

            using var conn = _conexion.CrearConexion();

            using var co = new SqlCommand();
            co.Connection = conn;

            try
            {
                co.CommandText = @$"SELECT Valor FROM [dbo].[Configuracion]
                                    WHERE Nombre = '{nombre}'";


                conn.Open();
                using SqlDataReader dr = co.ExecuteReader();

                while (dr.Read())
                {
                    valor = (string)dr["Valor"];
                }
            }
            catch (Exception)
            {
                throw;
            }
            finally
            {
                conn.Close();
            }

            return valor;
        }

        public void GuardarConfiguracion(string nombre, string valor)
        {
            using var conn = _conexion.CrearConexion();
            using var cmd = new SqlCommand();

            try
            {
                cmd.Connection = conn;
                cmd.CommandText = @"
                                    IF EXISTS (SELECT 1 FROM [dbo].[Configuracion] WHERE Nombre = @Nombre)
                                        UPDATE [dbo].[Configuracion] SET Valor = @Valor WHERE Nombre = @Nombre
                                    ELSE
                                        INSERT INTO [dbo].[Configuracion] (Nombre, Valor) VALUES (@Nombre, @Valor)
                                ";
                cmd.Parameters.AddWithValue("@Nombre", nombre);
                cmd.Parameters.AddWithValue("@Valor", valor);

                conn.Open();
                cmd.ExecuteNonQuery();
            }
            catch (Exception)
            {
                throw;
            }
        }

        public BanderaModel ObtenerBandera()
        {
            BanderaModel bandera = new BanderaModel();
            int identidad = 0;

            using var conn = _conexion.CrearConexion();

            using var co = new SqlCommand();
            co.Connection = conn;

            try
            {
                co.CommandText = @$"SELECT B.Pk_IdBandera, B.Nombre, AC.Pk_IdConfiguracion  FROM [dbo].[Bandera] B
                                    INNER JOIN [Autoservice].[Configuracion] AC
	                                    ON (B.Pk_IdBandera = AC.Valor AND AC.Nombre = 'Bandera')";


                conn.Open();
                using SqlDataReader dr = co.ExecuteReader();

                while (dr.Read())
                {
                    bandera.Id = (int)dr["Pk_IdBandera"];
                    identidad = (int)dr["Pk_IdConfiguracion"];
                }
            }
            catch (Exception)
            {
                throw;
            }
            finally
            {
                conn.Close();
            }
            bandera.Petrolera = ObtenerConfiguracionAutoservice("Sistema");
            bandera.Colores = ObtenerColoresBandera();
            return bandera;
        }

        public int ObtenerNivelAutoservicio()
        {
            int idNivel = 0;

            using var conn = _conexion.CrearConexion();

            using var co = new SqlCommand();
            co.Connection = conn;

            try
            {
                co.CommandText = @$"SELECT [Pk_IdNivel]
                                    FROM [Nivel]
                                    WHERE Nombre = 'Autoservicio'";


                conn.Open();
                using SqlDataReader dr = co.ExecuteReader();

                while (dr.Read())
                {
                    idNivel = (int)dr["Pk_IdNivel"];
                }
            }
            catch (Exception)
            {
                throw;
            }
            finally
            {
                conn.Close();
            }
            return idNivel;
        }
        public List<DispensadorModel> ObtenerDispensadoresByIdentificador(string identificador)
        {
            List<DispensadorModel> dispensadores = new List<DispensadorModel>();
            List<(int IdDispensador, bool Hibrido, bool? TiempoReal, int? Intervalo)> iddispensadores = new List<(int, bool, bool?, int?)>();

            int idDispensador = 0;

            using var conn = _conexion.CrearConexion();

            using var co = new SqlCommand();
            co.Connection = conn;

            try
            {
                conn.Open();

                // ModoHibrido solo existe en las bases con el script 02 aplicado
                co.CommandText = "SELECT COL_LENGTH('Autoservice.Dispositivo', 'ModoHibrido')";
                object columna = co.ExecuteScalar();
                string campoHibrido = (columna == null || columna is DBNull) ? "CAST(0 AS bit)" : "[ModoHibrido]";

                // Tiempo real: columnas del script 148
                co.CommandText = "SELECT COL_LENGTH('Autoservice.Dispositivo', 'IntervaloTiempoReal')";
                object columnaTiempoReal = co.ExecuteScalar();
                string camposTiempoReal = (columnaTiempoReal == null || columnaTiempoReal is DBNull)
                    ? "CAST(NULL AS bit) AS TiempoReal, CAST(NULL AS int) AS IntervaloTiempoReal"
                    : "[TiempoReal], [IntervaloTiempoReal]";

                co.CommandText = @$"SELECT [IdDispensador], {campoHibrido} AS ModoHibrido, {camposTiempoReal}
                                  FROM [Autoservice].[Dispositivo]
                                  WHERE Activo = 1 AND Identificador = '{identificador}'";

                using SqlDataReader dr = co.ExecuteReader();

                while (dr.Read())
                {
                    idDispensador = (int)dr["IdDispensador"];
                    bool hibrido = dr["ModoHibrido"] != DBNull.Value && (bool)dr["ModoHibrido"];
                    iddispensadores.Add((idDispensador, hibrido, dr["TiempoReal"] as bool?, dr["IntervaloTiempoReal"] as int?));
                }
            }
            catch (Exception)
            {
                throw;
            }
            finally
            {
                conn.Close();
            }

            foreach (var dispensador in iddispensadores)
            {
                DispensadorModel dis = new DispensadorModel();
                dis.IdDispensador = dispensador.IdDispensador;
                dis.TipoDispensador = 1;
                dis.Hibrido = dispensador.Hibrido;
                dis.TiempoReal = dispensador.TiempoReal;
                dis.IntervaloTiempoReal = dispensador.Intervalo;
                dis.Caras = ObtenerCarasByIdDispensador(dispensador.IdDispensador);
                dispensadores.Add(dis);
            }

            return dispensadores;
        }

        public List<DispensadorModel> ObtenerDispensadores()
        {
            List<DispensadorModel> dispensadores = new List<DispensadorModel>();
            List<int> iddispensadores = new List<int>();

            int idDispensador = 0;

            using var conn = _conexion.CrearConexion();

            using var co = new SqlCommand();
            co.Connection = conn;

            try
            {
                co.CommandText = @$"SELECT [Pk_IdDispensador]
                                  FROM [Dispensador]
                                  WHERE Activo = 1";


                conn.Open();
                using SqlDataReader dr = co.ExecuteReader();

                while (dr.Read())
                {
                    idDispensador = (int)dr["Pk_IdDispensador"];
                    iddispensadores.Add(idDispensador);
                }
            }
            catch (Exception)
            {
                throw;
            }
            finally
            {
                conn.Close();
            }

            foreach (var dispensador in iddispensadores)
            {
                DispensadorModel dis = new DispensadorModel();
                dis.IdDispensador = dispensador;
                dis.TipoDispensador = 1;
                dis.Caras = ObtenerCarasByIdDispensador(dispensador);
                dispensadores.Add(dis);
            }

            return dispensadores;
        }
        public List<CaraModel> ObtenerCarasByIdDispensador(int idDispensador)
        {
            List<CaraModel> caras = new List<CaraModel>();
            MangueraModel manguera = new MangueraModel();

            int NumeroCaras = 0;

            using var conn = _conexion.CrearConexion();

            using var co = new SqlCommand();
            co.Connection = conn;

            try
            {
                co.CommandText = @$"SELECT COUNT (DISTINCT NumeroCaraDispensador) Caras
                                    FROM DispensadorPosicion 
                                    WHERE Activo = 1 and Fk_IdDispensador  = {idDispensador}";


                conn.Open();
                using SqlDataReader dr = co.ExecuteReader();

                while (dr.Read())
                {
                    NumeroCaras= (int)dr["Caras"];
                }
            }
            catch (Exception)
            {
                throw;
            }
            finally
            {
                conn.Close();
            }
            for (int i = 1; i <= NumeroCaras; i++)
            {
                CaraModel caraModel = new CaraModel();
                caraModel.NumeroCara = i;
                caraModel.Posiciones = ObtenerPosicionesByIdDispensadorCara(idDispensador, i);
                var serialPantalla = ObtenerRecurso("SerialPantalla", "Posicion", caraModel.Posiciones[0].IdPosicion);
                caraModel.SerialPantalla = string.IsNullOrWhiteSpace(serialPantalla) ? null : serialPantalla;
                //caraModel.SerialPantalla = ObtenerRecurso("SerialPantalla", "Posicion", caraModel.Posiciones[0].IdPosicion);
                caras.Add(caraModel);
            }
            return caras;

        }
        public List<PosicionModel> ObtenerPosicionesByIdDispensadorCara(int idDispensador, int Cara)
        {
            List<PosicionModel> posiciones = new List<PosicionModel>();
            PosicionModel posicion = new PosicionModel();
            List<int> idposiciones = new List<int>();

            using var conn = _conexion.CrearConexion();

            using var co = new SqlCommand();
            co.Connection = conn;
            int idPosicion = 0;
            try
            {
                co.CommandText = @$"SELECT Pk_IdPosicion 
                                    FROM DispensadorPosicion 
                                    WHERE Fk_IdDispensador = {idDispensador} AND NumeroCaraDispensador = {Cara}";


                conn.Open();
                using SqlDataReader dr = co.ExecuteReader();

                while (dr.Read())
                {
                    idPosicion = (int)dr["Pk_IdPosicion"];
                    idposiciones.Add(idPosicion);
                }
            }
            catch (Exception)
            {
                throw;
            }
            finally
            {
                conn.Close();
            }

            foreach (var id in idposiciones)
            {   
                PosicionModel posicionModel = new PosicionModel();
                posicionModel.IdPosicion = id;
                posicionModel.Mangueras = ObtenerMangueraByIdPosicion(id);
                posicionModel.Formato = ObtenerFormatosByIdPosicion(id);
                var codigoTankio = ObtenerRecurso("QRTankio", "Posicion", id);
                posicionModel.CodigoTankio = string.IsNullOrWhiteSpace(codigoTankio) ? null : codigoTankio;
                //posicionModel.CodigoTankio = ObtenerRecurso("QRTankio", "Posicion", id);
                posiciones.Add(posicionModel);
            }
            return posiciones;
        }

        private FormatoModel ObtenerFormatosByIdPosicion(int id)
        {
           FormatoModel formato = new FormatoModel();


            using var conn = _conexion.CrearConexion();

            using var co = new SqlCommand();
            co.Connection = conn;

            try
            {
                co.CommandText = @$"SELECT FormatoDinero, FormatoVolumen, FormatoPrecio, Fk_IdDigitosPosicion
                                    FROM DispensadorPosicion
                                    WHERE Pk_IdPosicion = {id}";


                conn.Open();
                using SqlDataReader dr = co.ExecuteReader();

                while (dr.Read())
                {
                    formato.FormatoDinero = (int)dr["FormatoDinero"];
                    formato.FormatoVolumen = (int)dr["FormatoVolumen"];
                    formato.FormatoPrecio = (int)dr["FormatoPrecio"];

                    // Mismos limites del "Lleno" de NSX (Full6Digits y Full7Digits de EspanolOperador.xaml) entre 10^FormatoDinero
                    bool sieteDigitos = dr["Fk_IdDigitosPosicion"] != DBNull.Value && Convert.ToInt32(dr["Fk_IdDigitosPosicion"]) == 2;
                    formato.DigitosPosicion = sieteDigitos ? 7 : 6;
                    formato.MaximoDinero = (sieteDigitos ? 9999990d : 999990d) / Math.Pow(10, formato.FormatoDinero);
                }
            }
            catch (Exception)
            {
                throw;
            }
            finally
            {
                conn.Close();
            }

            return formato;
        }

        public List<MangueraModel> ObtenerMangueraByIdPosicion (int idPosicion)
        {
            List<MangueraModel> mangueras = new List<MangueraModel>();
            

            using var conn = _conexion.CrearConexion();

            using var co = new SqlCommand();
            co.Connection = conn;

            try
            {
                co.CommandText = @$"SELECT PG.Pk_IdPosicionGrado, PG.NumeroManguera, P.Pk_IdProducto, P.Descripcion, PP.Precio, PPub.Precio PrecioPublico, UM.UnidadMedida
                                    FROM PosicionGrado PG 
                                    INNER JOIN TanqueCombustible T
	                                    ON PG.Fk_IdTanque = T.Pk_IdTanque
                                    INNER JOIN Producto P
	                                    ON P.Pk_IdProducto = T.Fk_IdProducto
									INNER JOIN Nivel N 
										ON N.Nombre = 'Autoservicio'
                                    INNER JOIN PrecioProducto PP 
	                                    ON PP.Fk_IdProducto = P.Pk_IdProducto AND PP.Fk_IdNivel = N.Pk_IdNivel
                                    INNER JOIN UnidadMedida UM
		                                ON P.Fk_IdUnidadMedida = UM.Pk_IdUnidadMedida
                                    LEFT JOIN PrecioProducto PPub ON PPub.Fk_IdProducto = P.Pk_IdProducto AND PPub.Fk_IdNivel = PG.Fk_IdNivel AND PPub.Activo = 1
                                    WHERE PG.Fk_IdPosicion = {idPosicion} AND PP.Activo = 1 AND PG.Activo = 1
                                    ORDER BY 1";


                conn.Open();
                using SqlDataReader dr = co.ExecuteReader();

                while (dr.Read())
                {
                    int posgrado = 0;
                    posgrado = (int)dr["Pk_IdPosicionGrado"];
                    MangueraModel manguera = new MangueraModel();
                    manguera.Numero = (int)dr["NumeroManguera"];
                    manguera.IdPosicionGrado = posgrado;
                    ProductoModel producto = new ProductoModel();
                    producto.IdProducto = (int)dr["Pk_IdProducto"];
                    producto.NombreProducto = (string)dr["Descripcion"];
                    producto.Precio = Convert.ToDecimal(dr["Precio"]);
                    producto.PrecioPublico = dr["PrecioPublico"] == DBNull.Value ? null : Convert.ToDecimal(dr["PrecioPublico"]);
                    producto.UnidadMedida = (string)dr["UnidadMedida"];
                    var maxPresetStr = ObtenerRecurso("MaximoPreset", "Producto", producto.IdProducto);

                    producto.MaximoPreset = decimal.TryParse(
                        maxPresetStr?.Replace(',', '.'),
                        NumberStyles.Any,
                        CultureInfo.InvariantCulture,
                        out var val
                    ) ? val : null;
                    //producto.MaximoPreset = Convert.ToDecimal(ObtenerRecurso("MaximoPreset", "Producto", producto.IdProducto));
                    manguera.Producto = producto;
                    var lado = ObtenerRecurso("Lado", "PosicionGrado", posgrado);
                    var color = ObtenerRecurso("Color", "PosicionGrado", posgrado);
                    manguera.Lado = string.IsNullOrWhiteSpace(lado) ? null : lado;
                    manguera.Color = string.IsNullOrWhiteSpace(color) ? null : color;
                    //manguera.Lado = ObtenerRecurso("Lado","PosicionGrado",posgrado);
                    //manguera.Color = ObtenerRecurso("Color", "PosicionGrado", posgrado);
                    mangueras.Add(manguera);
                }
            }
            catch (Exception)
            {
                throw;
            }
            finally
            {
                conn.Close();
            }

            return mangueras;

        }

        public List<FormaPagoModel> ObtenerFormasDePago()
        {
            List<FormaPagoModel> formasPago = new List<FormaPagoModel>();

            using var conn = _conexion.CrearConexion();

            using var co = new SqlCommand();
            co.Connection = conn;

            try
            {
                co.CommandText = @$"SELECT AFP.IdFormaPagoAuto, FPFP.Pk_IdFormaPago, FPFP.Descripcion, AFP.Activo FROM [Autoservice].[FormaPago] AFP
                                    INNER JOIN [FormaPago].[FormaPago] FPFP
	                                    ON AFP.FK_IdFormaPago = FPFP.Pk_IdFormaPago
                                    WHERE AFP.Activo = 1";


                conn.Open();
                using SqlDataReader dr = co.ExecuteReader();

                while (dr.Read())
                {
                    FormaPagoModel formaPago = new FormaPagoModel();
                    formaPago.IdFormaPago = (int)dr["IdFormaPagoAuto"];
                    formaPago.IdFormaPagoSistema = (int)dr["Pk_IdFormaPago"];
                    formaPago.Nombre = (string)dr["Descripcion"];
                    formaPago.Activo = (bool)dr["Activo"];
                    formasPago.Add(formaPago);
                }
            }
            catch (Exception)
            {
                throw;
            }
            finally
            {
                conn.Close();
            }

            return formasPago;

        }

        // Formas que el vendedor puede anclar: las habilitadas en Autoservice.FormaPagoVendedor y activas en NSX;
        // aqui el id es el del sistema. Sin la tabla (BD sin el script 07) se ofrecen las activas, como antes.
        public List<FormaPagoModel> ObtenerFormasDePagoVendedor()
        {
            List<FormaPagoModel> formasPago = new List<FormaPagoModel>();

            using var conn = _conexion.CrearConexion();

            using var co = new SqlCommand();
            co.Connection = conn;

            try
            {
                co.CommandText = @"IF OBJECT_ID('Autoservice.FormaPagoVendedor', 'U') IS NULL
                                       SELECT Pk_IdFormaPago, Descripcion, Activo FROM [FormaPago].[FormaPago]
                                       WHERE Activo = 1 AND NombreFormaPago <> 'QRVueltos'
                                   ELSE
                                       SELECT f.Pk_IdFormaPago, f.Descripcion, f.Activo FROM [FormaPago].[FormaPago] f
                                       INNER JOIN [Autoservice].[FormaPagoVendedor] v ON v.Fk_IdFormaPago = f.Pk_IdFormaPago
                                       WHERE f.Activo = 1 AND v.Activo = 1";

                conn.Open();
                using SqlDataReader dr = co.ExecuteReader();

                while (dr.Read())
                {
                    FormaPagoModel formaPago = new FormaPagoModel();
                    formaPago.IdFormaPago = (int)dr["Pk_IdFormaPago"];
                    formaPago.IdFormaPagoSistema = (int)dr["Pk_IdFormaPago"];
                    formaPago.Nombre = (string)dr["Descripcion"];
                    formaPago.Activo = (bool)dr["Activo"];
                    formasPago.Add(formaPago);
                }
            }
            catch (Exception)
            {
                throw;
            }
            finally
            {
                conn.Close();
            }

            return formasPago;
        }

        // Administracion: todas las formas activas de NSX con su interruptor para el vendedor
        public List<FormaPagoModel> ObtenerFormasDePagoVendedorAdmin()
        {
            var formasPago = new List<FormaPagoModel>();

            using var conn = _conexion.CrearConexion();
            using var co = new SqlCommand(@"IF OBJECT_ID('Autoservice.FormaPagoVendedor', 'U') IS NULL
                                                SELECT f.Pk_IdFormaPago, f.Descripcion, CAST(0 AS BIT) AS Habilitada FROM [FormaPago].[FormaPago] f WHERE f.Activo = 1
                                            ELSE
                                                SELECT f.Pk_IdFormaPago, f.Descripcion, ISNULL(v.Activo, 0) AS Habilitada FROM [FormaPago].[FormaPago] f
                                                LEFT JOIN [Autoservice].[FormaPagoVendedor] v ON v.Fk_IdFormaPago = f.Pk_IdFormaPago
                                                WHERE f.Activo = 1
                                            ORDER BY 1", conn);

            conn.Open();
            using SqlDataReader dr = co.ExecuteReader();
            while (dr.Read())
            {
                formasPago.Add(new FormaPagoModel
                {
                    IdFormaPago = (int)dr["Pk_IdFormaPago"],
                    IdFormaPagoSistema = (int)dr["Pk_IdFormaPago"],
                    Nombre = (string)dr["Descripcion"],
                    Activo = (bool)dr["Habilitada"]
                });
            }

            return formasPago;
        }

        // Deja habilitadas solo las formas indicadas; el resto queda apagado
        public void GuardarFormasPagoVendedor(List<FormaPagoVendedorRequest> formasPago)
        {
            if (formasPago == null)
                throw new Exception("No hay formas de pago para configurar");

            using var conn = _conexion.CrearConexion();
            conn.Open();

            using (var existe = new SqlCommand("SELECT OBJECT_ID('Autoservice.FormaPagoVendedor', 'U')", conn))
            {
                if (existe.ExecuteScalar() is DBNull or null)
                    throw new Exception("Falta la tabla Autoservice.FormaPagoVendedor (script 07_FormaPagoVendedor.sql)");
            }

            using var transaction = conn.BeginTransaction();
            try
            {
                foreach (var fp in formasPago)
                {
                    using var cmd = new SqlCommand(@"IF NOT EXISTS (SELECT 1 FROM [FormaPago].[FormaPago] WHERE Pk_IdFormaPago = @IdFormaPago)
                                                         THROW 50001, 'Forma de pago inexistente', 1;
                                                     IF EXISTS (SELECT 1 FROM [Autoservice].[FormaPagoVendedor] WHERE Fk_IdFormaPago = @IdFormaPago)
                                                         UPDATE [Autoservice].[FormaPagoVendedor] SET Activo = @Activo WHERE Fk_IdFormaPago = @IdFormaPago
                                                     ELSE
                                                         INSERT INTO [Autoservice].[FormaPagoVendedor] (Fk_IdFormaPago, Activo) VALUES (@IdFormaPago, @Activo)", conn, transaction);
                    cmd.Parameters.AddWithValue("@IdFormaPago", fp.IdFormaPago);
                    cmd.Parameters.AddWithValue("@Activo", fp.Activo);
                    cmd.ExecuteNonQuery();
                }

                transaction.Commit();
            }
            catch (Exception)
            {
                transaction.Rollback();
                throw;
            }
        }

        public List<FormaPagoModel> ObtenerFormasDePagoAdmin()
        {
            List<FormaPagoModel> formasPago = new List<FormaPagoModel>();

            using var conn = _conexion.CrearConexion();

            using var co = new SqlCommand();
            co.Connection = conn;

            try
            {
                co.CommandText = @$"SELECT AFP.IdFormaPagoAuto, FPFP.Pk_IdFormaPago, FPFP.Descripcion, AFP.Activo FROM [Autoservice].[FormaPago] AFP
                                    INNER JOIN [FormaPago].[FormaPago] FPFP
	                                    ON AFP.FK_IdFormaPago = FPFP.Pk_IdFormaPago";

                conn.Open();
                using SqlDataReader dr = co.ExecuteReader();

                while (dr.Read())
                {
                    FormaPagoModel formaPago = new FormaPagoModel();
                    formaPago.IdFormaPago = (int)dr["IdFormaPagoAuto"];
                    formaPago.IdFormaPagoSistema = (int)dr["Pk_IdFormaPago"];
                    formaPago.Nombre = (string)dr["Descripcion"];
                    formaPago.Activo = (bool)dr["Activo"];
                    formasPago.Add(formaPago);
                }
            }
            catch (Exception)
            {
                throw;
            }
            finally
            {
                conn.Close();
            }

            var slotsFijos = new Dictionary<int, string>
            {
                { 1, "Datafono" },
                { 2, "Nequi" },
                { 3, "QRVueltos" }
            };

            foreach (var slot in slotsFijos)
            {
                if (!formasPago.Any(f => f.IdFormaPago == slot.Key))
                {
                    formasPago.Add(new FormaPagoModel
                    {
                        IdFormaPago = slot.Key,
                        IdFormaPagoSistema = 0,
                        Nombre = slot.Value,
                        Activo = false
                    });
                }
            }  

            return formasPago.OrderBy(f => f.IdFormaPago).ToList();
        }

        public List<FidelidadModel> ObtenerFidelidad()
        {
            List<FidelidadModel> fidelidadModels = new List<FidelidadModel>();

            using var conn = _conexion.CrearConexion();

            using var co = new SqlCommand();
            co.Connection = conn;

            try
            {
                co.CommandText = @$"SELECT IdFidelidadAuto, Descripcion
                                        FROM [Autoservice].[Fidelidad]
                                    WHERE Activo = 1";


                conn.Open();
                using SqlDataReader dr = co.ExecuteReader();

                while (dr.Read())
                {
                    FidelidadModel fidelidad = new FidelidadModel();
                    fidelidad.IdFidelidad = (int)dr["IdFidelidadAuto"];
                    fidelidad.Nombre = (string)dr["Descripcion"];
                    fidelidadModels.Add(fidelidad);
                }
            }
            catch (Exception)
            {
                throw;
            }
            finally
            {
                conn.Close();
            }

            return fidelidadModels;

        }

        public int ObtenerIdFormaPagoNSX(int idFormaPagoAuto)
        {
            int idFormaPago = 0;

            using var conn = _conexion.CrearConexion();

            using var co = new SqlCommand();
            co.Connection = conn;

            try
            {
                co.CommandText = @$"SELECT AFP.IdFormaPagoAuto FROM [Autoservice].[FormaPago] AFP
                                    INNER JOIN [FormaPago].[FormaPago] FPFP
	                                        ON AFP.FK_IdFormaPago = FPFP.Pk_IdFormaPago
                                    WHERE FPFP.Pk_IdFormaPago = @IdFormaPagoAuto";

                co.Parameters.AddWithValue("@IdFormaPagoAuto", idFormaPagoAuto);
                conn.Open();
                using SqlDataReader dr = co.ExecuteReader();

                while (dr.Read())
                {
                    idFormaPago = (int)dr["IdFormaPagoAuto"];
                }
            }
            catch (Exception)
            {
                throw;
            }
            finally
            {
                conn.Close();
            }

            return idFormaPago;

        }

        public MarcacionRapidaModel ObtenerMarcacionesRapidas()
        {
            MarcacionRapidaModel marcacionRapidas = new MarcacionRapidaModel();
            string[] _ArrayDinero = ObtenerConfiguracionEstacion("DineroPredeterminado").Split('|');
            string[] _ArrayVolumen = ObtenerConfiguracionEstacion("VolumenPredeterminado").Split('|');

            marcacionRapidas.Dinero = _ArrayDinero
                                    .Take(3)
                                    .Select(x => x.Replace(',', '.'))
                                    .Select(x => double.TryParse(
                                        x,
                                        NumberStyles.Any,
                                        CultureInfo.InvariantCulture,
                                        out var val
                                    ) ? val : 0)
                                    .ToList();
            marcacionRapidas.Volumen = _ArrayVolumen
                                    .Take(3)
                                    .Select(x => x.Replace(',', '.'))
                                    .Select(x => double.TryParse(
                                        x,
                                        NumberStyles.Any,
                                        CultureInfo.InvariantCulture,
                                        out var val
                                    ) ? val : 0)
                                    .ToList();

            return marcacionRapidas;

        }
        public int ObtenerIdTurnoByIdentificador(string identificador)
        {
            int idTurno = 0;
            using var conn = _conexion.CrearConexion();

            using var co = new SqlCommand();
            co.Connection = conn;

            try
            {
                co.CommandText = @$"SELECT TOP 1 Pk_IdTurno FROM Turnos.Turno 
                                                  WHERE MacTerminal = '{identificador}' AND Fk_IdEstadoTurno = 1
                                                  ORDER BY 1 DESC";


                conn.Open();
                using SqlDataReader dr = co.ExecuteReader();

                while (dr.Read())
                {
                    idTurno = (int)dr["Pk_IdTurno"];
                }
            }
            catch (Exception)
            {
                throw;
            }
            finally
            {
                conn.Close();
            }

            return idTurno;
        }

        public int ObtenerIdTurnoAbiertoByIslero(int idIslero)
        {
            using var conn = _conexion.CrearConexion();
            using var co = new SqlCommand();
            co.Connection = conn;

            co.CommandText = @"SELECT TOP 1 Pk_IdTurno FROM Turnos.Turno
                               WHERE Fk_IdIslero = @IdIslero AND Fk_IdEstadoTurno = 1
                               ORDER BY Pk_IdTurno DESC";
            co.Parameters.AddWithValue("@IdIslero", idIslero);

            conn.Open();
            object idTurno = co.ExecuteScalar();

            return idTurno == null || idTurno is DBNull ? 0 : Convert.ToInt32(idTurno);
        }

        // Agrega formas de pago a una venta de vendedor ya terminada; sin filas la venta es efectivo, lo no anclado sigue asi
        public NSXAutoservice.Models.Response.ResultadoOperacion<object> AnclarFormasPago(AnclarFormaPagoRequest request)
        {
            var vendedor = ObtenerVendedorByDocumento(request.Documento);
            if (vendedor == null)
                return FallaAnclaje("Vendedor no encontrado");
            if (!vendedor.Activo)
                return FallaAnclaje("El vendedor está inactivo");

            var permitidas = ObtenerFormasDePagoVendedor().Select(f => f.IdFormaPagoSistema).ToHashSet();
            foreach (var fp in request.FormasPago)
            {
                if (!permitidas.Contains(fp.IdFormaPago))
                    return FallaAnclaje($"Forma de pago no permitida para el vendedor: {fp.IdFormaPago}");
            }

            using var conn = _conexion.CrearConexion();
            conn.Open();
            using var transaction = conn.BeginTransaction(IsolationLevel.Serializable);

            try
            {
                double valorVenta;
                int idTurno;
                int idIslero;
                int estadoTurno;

                using (var cmd = new SqlCommand(@"SELECT v.ValorTotal, pr.Fk_IdTurno, t.Fk_IdIslero, t.Fk_IdEstadoTurno
                                                  FROM dbo.Venta v
                                                  INNER JOIN DispensadorPosicionProgramacion pr ON pr.Fk_IdVenta = v.Pk_IdVenta
                                                  LEFT JOIN Turnos.Turno t ON t.Pk_IdTurno = pr.Fk_IdTurno
                                                  WHERE v.Pk_IdVenta = @IdVenta", conn, transaction))
                {
                    cmd.Parameters.AddWithValue("@IdVenta", request.IdVenta);
                    using var dr = cmd.ExecuteReader();
                    if (!dr.Read())
                        return FallaAnclaje("Venta no encontrada");

                    valorVenta = Convert.ToDouble(dr["ValorTotal"]);
                    idTurno = dr["Fk_IdTurno"] == DBNull.Value ? 0 : Convert.ToInt32(dr["Fk_IdTurno"]);
                    idIslero = dr["Fk_IdIslero"] == DBNull.Value ? 0 : Convert.ToInt32(dr["Fk_IdIslero"]);
                    estadoTurno = dr["Fk_IdEstadoTurno"] == DBNull.Value ? 0 : Convert.ToInt32(dr["Fk_IdEstadoTurno"]);
                }

                if (idTurno <= 0 || idIslero != vendedor.IdIslero)
                    return FallaAnclaje("La venta no corresponde a un turno de este vendedor");
                if (estadoTurno != 1)
                    return FallaAnclaje("El turno de la venta está cerrado");

                double anclado;
                using (var cmd = new SqlCommand(@"SELECT ISNULL(SUM(Valor), 0) FROM FormaPago.DetalleFormaPago WITH (UPDLOCK, HOLDLOCK)
                                                  WHERE ConsecutivoReferenciaTabla = @IdVenta AND Fk_IdTipoCompra = 1 AND Activa = 1", conn, transaction))
                {
                    cmd.Parameters.AddWithValue("@IdVenta", request.IdVenta);
                    anclado = Convert.ToDouble(cmd.ExecuteScalar());
                }

                double nuevo = request.FormasPago.Sum(f => f.Valor);
                if (anclado + nuevo > valorVenta + 0.01)
                    return FallaAnclaje($"Las formas de pago ({anclado + nuevo}) superan el valor de la venta ({valorVenta})");

                // Formas que consumen un bono (QR de vueltos)
                var formasQr = new HashSet<int>();
                using (var cmd = new SqlCommand("SELECT Pk_IdFormaPago FROM [FormaPago].[FormaPago] WHERE NombreFormaPago = 'QRVueltos'", conn, transaction))
                using (var dr = cmd.ExecuteReader())
                {
                    while (dr.Read())
                        formasQr.Add(Convert.ToInt32(dr["Pk_IdFormaPago"]));
                }

                foreach (var fp in request.FormasPago)
                {
                    int idDetalle;
                    using (var cmd = new SqlCommand(@"INSERT INTO [FormaPago].[DetalleFormaPago]
                                                      ([Valor],[Identificador],[ConsecutivoReferenciaTabla],[Fk_IdTipoCompra],[Fk_IdFormaPago],[Fk_IdTurno],[Activa])
                                                      VALUES (@Valor, @Identificador, @IdVenta, 1, @IdFormaPago, @IdTurno, 1);
                                                      SELECT CAST(SCOPE_IDENTITY() AS INT)", conn, transaction))
                    {
                        cmd.Parameters.AddWithValue("@Valor", fp.Valor);
                        cmd.Parameters.AddWithValue("@Identificador", fp.Identificador ?? "");
                        cmd.Parameters.AddWithValue("@IdVenta", request.IdVenta);
                        cmd.Parameters.AddWithValue("@IdFormaPago", fp.IdFormaPago);
                        cmd.Parameters.AddWithValue("@IdTurno", idTurno);
                        idDetalle = Convert.ToInt32(cmd.ExecuteScalar());
                    }

                    if (!formasQr.Contains(fp.IdFormaPago))
                        continue;

                    // Bono de vueltos: como en el autoservicio, solo vale en estado Creado y por su valor exacto;
                    // al anclarlo queda Usado y unido a este detalle de pago
                    if (string.IsNullOrWhiteSpace(fp.Identificador))
                    {
                        transaction.Rollback();
                        return FallaAnclaje("El pago con QR necesita el código del bono");
                    }

                    using var usar = new SqlCommand(@"UPDATE [Autoservice].[Vueltos]
                                                      SET IdEstadoVuelto = @Usado, FechaUso = GETDATE(), IdDetalleFormaPago = @IdDetalle,
                                                          IdFormaPago = @IdFormaPago, IdTurno = @IdTurno
                                                      WHERE Codigo = @Codigo AND IdEstadoVuelto = @Creado AND Valor = @Valor", conn, transaction);
                    usar.Parameters.AddWithValue("@Usado", (int)EstadoVueltoEnum.Usado);
                    usar.Parameters.AddWithValue("@Creado", (int)EstadoVueltoEnum.Creado);
                    usar.Parameters.AddWithValue("@IdDetalle", idDetalle);
                    usar.Parameters.AddWithValue("@IdFormaPago", fp.IdFormaPago);
                    usar.Parameters.AddWithValue("@IdTurno", idTurno);
                    usar.Parameters.AddWithValue("@Codigo", fp.Identificador.Trim());
                    usar.Parameters.AddWithValue("@Valor", fp.Valor);

                    if (usar.ExecuteNonQuery() == 0)
                    {
                        transaction.Rollback();
                        return FallaAnclaje($"El bono {fp.Identificador} no existe, ya fue usado o su valor no coincide");
                    }
                }

                transaction.Commit();

                double total = anclado + nuevo;
                return new NSXAutoservice.Models.Response.ResultadoOperacion<object>
                {
                    Exitoso = true,
                    Data = new { idVenta = request.IdVenta, valorVenta, anclado = total, efectivo = valorVenta - total },
                    Mensaje = "Formas de pago ancladas correctamente"
                };
            }
            catch (Exception)
            {
                transaction.Rollback();
                throw;
            }
        }

        private static NSXAutoservice.Models.Response.ResultadoOperacion<object> FallaAnclaje(string mensaje)
        {
            return new NSXAutoservice.Models.Response.ResultadoOperacion<object> { Exitoso = false, Mensaje = mensaje };
        }

        public Dictionary<string, object> ObtenerTurnoPorId(int idTurno)
        {
            Dictionary<string, object> resultado = null;
            using var conn = _conexion.CrearConexion();

            using var co = new SqlCommand();
            co.Connection = conn;

            try
            {
                co.CommandText = @"SELECT Pk_IdTurno, MacTerminal, Fk_IdEstadoTurno, Fk_IdPosicionApertura
                                    FROM Turnos.Turno
                                    WHERE Pk_IdTurno = @IdTurno";
                co.Parameters.AddWithValue("@IdTurno", idTurno);

                conn.Open();
                using SqlDataReader dr = co.ExecuteReader();

                while (dr.Read())
                {
                    resultado = new Dictionary<string, object>
                    {
                        ["pkIdTurno"] = dr["Pk_IdTurno"],
                        ["macTerminal"] = dr["MacTerminal"],
                        ["fkIdEstadoTurno"] = dr["Fk_IdEstadoTurno"],
                        ["fkIdPosicionApertura"] = dr["Fk_IdPosicionApertura"]
                    };
                }
            }
            catch (Exception)
            {
                throw;
            }
            finally
            {
                conn.Close();
            }

            return resultado;
        }

        public int ObtenerIdTurnoByDocumento(int idislero)
        {
            int idTurno = 0;
            using var conn = _conexion.CrearConexion();

            using var co = new SqlCommand();
            co.Connection = conn;

            try
            {
                co.CommandText = @$"SELECT TOP 1 Pk_IdTurno FROM Turnos.Turno 
                                                  WHERE Fk_IdIslero = '{idislero}' AND Fk_IdEstadoTurno = 1
                                                  ORDER BY 1 DESC";


                conn.Open();
                using SqlDataReader dr = co.ExecuteReader();

                while (dr.Read())
                {
                    idTurno = (int)dr["Pk_IdTurno"];
                }
            }
            catch (Exception)
            {
                throw;
            }
            finally
            {
                conn.Close();
            }

            return idTurno;
        }

        public int ObtenerUltimaProgramacionByIdPosicion(int posicion, DateTime fechaSolicitud)
        {
            int idPreset = 0;
            using var conn = _conexion.CrearConexion();

            using var co = new SqlCommand();
            co.Connection = conn;

            try
            {
                co.CommandText = @$"SELECT Pk_IdDispensadorPosicionEstado FROM DispensadorPosicionProgramacion
                                    WHERE  Fk_IdEstadoProgramacion = 1 AND Fk_IdPosicion = {posicion} AND FechaInicial > '{fechaSolicitud.ToString("yyyyMMdd HH:mm:ss")}'";


                conn.Open();
                using SqlDataReader dr = co.ExecuteReader();

                while (dr.Read())
                {
                    idPreset = (int)dr["Pk_IdDispensadorPosicionEstado"];
                }
            }
            catch (Exception)
            {
                throw;
            }
            finally
            {
                conn.Close();
            }

            return idPreset;
        }

        public void InsertarFormasPagoAutoservicio(int idPreset, PresetRequest preset)
        {
            using var conn = _conexion.CrearConexion();
            conn.Open();

            using var transaction = conn.BeginTransaction();

            try
            {
                foreach (var fp in preset.FormasPago)
                {
                    //LogInfo($"Insertando forma pago {JsonConvert.SerializeObject(fp)}");
                    int idFormaPago = ObtenerIdFormaPagoNSX(fp.IdFormaPago);
                    //if (idFormaPago == 0)
                    //    throw new InvalidOperationException($"Forma de pago inválida. Id recibido: {fp.IdFormaPago}");

                    //int idTurno = ObtenerIdTurnoByIdentificador(preset.Identificador);
                    int idTurno = preset.IdTurno;
                    //LogInfo("Turno recibido " + idTurno);
                    bool esQr = idFormaPago == 3; // define este ID
                    //LogInfo($"Insertando forma pago {fp.IdFormaPago}");
                    if (esQr)
                    {
                        string codigoQr = fp.Identificador;

                        bool reservado = ReservarVuelto(codigoQr, fp.Valor);

                        if (!reservado)
                            throw new InvalidOperationException($"No se pudo reservar el vuelto: {codigoQr}\nEl codigo no existe o el valor es incorrecto");
                    }

                    // 1️⃣ Insertar FormaPago y obtener ID
                    int idDetalleFormaPagoAuto;

                    using (var cmd = new SqlCommand())
                    {
                        cmd.Connection = conn;
                        cmd.Transaction = transaction;

                        cmd.CommandText = @"
                            INSERT INTO [FormaPago].[DetalleFormaPagoAutoServicio]
                            (
                                Fk_IdPosicion,
                                Valor,
                                Identificador,
                                Fk_IdTipoCompra,
                                Fk_IdFormaPago,
                                Fk_IdTurno,
                                Fk_IdPosicionProgramacion,
                                Fecha
                            )
                            VALUES
                            (
                                @IdPosicion,
                                @Valor,
                                @Identificador,
                                @IdTipoCompra,
                                @IdFormaPago,
                                @IdTurno,
                                @IdPreset,
                                @Fecha
                            );

                            SELECT SCOPE_IDENTITY();
                            ";

                        cmd.Parameters.AddWithValue("@IdPosicion", preset.IdPosicion);
                        cmd.Parameters.AddWithValue("@Valor", fp.Valor);
                        cmd.Parameters.AddWithValue("@IdTipoCompra", 1);
                        cmd.Parameters.AddWithValue("@IdFormaPago", fp.IdFormaPago);
                        cmd.Parameters.AddWithValue("@IdTurno", idTurno);
                        cmd.Parameters.AddWithValue("@IdPreset", idPreset);
                        cmd.Parameters.AddWithValue("@Fecha", DateTime.Now);
                        if(esQr)
                            cmd.Parameters.AddWithValue("@Identificador", fp.Identificador ?? (object)DBNull.Value);
                        else
                            cmd.Parameters.AddWithValue("@Identificador", "");

                        idDetalleFormaPagoAuto = Convert.ToInt32(cmd.ExecuteScalar());
                    }

                    // 2️⃣ Parsear JSON del identificador
                    if (fp.IdFormaPago == 2)
                    {
                        if (!string.IsNullOrEmpty(fp.Identificador))
                        {
                            dynamic json = Newtonsoft.Json.JsonConvert.DeserializeObject(fp.Identificador);

                            var response = Newtonsoft.Json.JsonConvert.DeserializeObject(
                                json?.content?.response?.ToString() ?? "{}"
                            );

                            string franquicia = response?.content?.Franquicia;
                            string tipoCuenta = response?.content?.Tipo_cuenta;
                            string ultimos4 = response?.content?.Ultimos_digitos_tarjeta;
                            string tipoOperacion = response?.content?.Tipo_operacion?.ToString();

                            //LogInfo($"Insertando forma pago {JsonConvert.SerializeObject(response)}");

                            // 3️⃣ Insertar DetalleTransaccion
                            using var cmdTrans = new SqlCommand();
                            cmdTrans.Connection = conn;
                            cmdTrans.Transaction = transaction;

                            cmdTrans.CommandText = @"
                            INSERT INTO [FormaPago].[DetalleTransaccion]
                            (
                                Fk_IdDetalleFormaPagoAutoServicio,
                                Franchise,
                                AccountType,
                                LastFourDigitsCard,
                                operatorType,
                                Descripcion
                            )
                            VALUES
                            (
                                @IdDetalleFormaPagoAuto,
                                @Franchise,
                                @AccountType,
                                @LastFour,
                                @OperatorType,
                                @Descripcion
                            )";

                            cmdTrans.Parameters.AddWithValue("@IdDetalleFormaPagoAuto", idDetalleFormaPagoAuto);
                            cmdTrans.Parameters.AddWithValue("@Franchise", (object)franquicia ?? DBNull.Value);
                            cmdTrans.Parameters.AddWithValue("@AccountType", (object)tipoCuenta ?? DBNull.Value);
                            cmdTrans.Parameters.AddWithValue("@LastFour", (object)ultimos4 ?? DBNull.Value);
                            cmdTrans.Parameters.AddWithValue("@OperatorType", (object)tipoOperacion ?? DBNull.Value);
                            cmdTrans.Parameters.AddWithValue("@Descripcion", "Pago autoservicio");

                            cmdTrans.ExecuteNonQuery();
                        }
                    }
                }

                transaction.Commit();
            }
            catch (Exception ex)
            {
                LogInfo(ex.ToString());
                transaction.Rollback();
                throw;
            }
        }

        public void InsertarFormasPagoAutoservicioGNE(int idPreset, PresetRequest preset)
        {
            using var conn = _conexion.CrearConexion();
            conn.Open();

            using var transaction = conn.BeginTransaction();

            try
            {
                foreach (var fp in preset.FormasPago)
                {
                    //LogInfo($"Insertando forma pago {JsonConvert.SerializeObject(fp)}");
                    int idFormaPago = ObtenerIdFormaPagoNSX(fp.IdFormaPago);
                    //if (idFormaPago == 0)
                    //    throw new InvalidOperationException($"Forma de pago inválida. Id recibido: {fp.IdFormaPago}");

                    //int idTurno = ObtenerIdTurnoByIdentificador(preset.Identificador);
                    int idTurno = preset.IdTurno;
                    //LogInfo("Turno recibido " + idTurno);
                    bool esQr = idFormaPago == 3; // define este ID
                    //LogInfo($"Insertando forma pago {fp.IdFormaPago}");
                    if (esQr)
                    {
                        string codigoQr = fp.Identificador;

                        bool reservado = ReservarVuelto(codigoQr, fp.Valor);

                        if (!reservado)
                            throw new InvalidOperationException($"No se pudo reservar el vuelto: {codigoQr}\nEl codigo no existe o el valor es incorrecto");
                    }

                    // 0️⃣ Si es tarjeta (datáfono), parsear el JSON antes de insertar para sacar el autorizationCode
                    bool esTarjeta = fp.IdFormaPago == 2;
                    string franquicia = null, tipoCuenta = null, ultimos4 = null, autorizationCode = null;
                    string tipoOperacion = "CREDIBANCO";

                    if (esTarjeta && !string.IsNullOrEmpty(fp.Identificador))
                    {
                        var outer = Newtonsoft.Json.Linq.JObject.Parse(fp.Identificador);

                        // nivel 2: outer.content.response es un string con JSON adentro
                        var respJson = outer.SelectToken("content.response")?.ToString();
                        var respObj = string.IsNullOrEmpty(respJson)
                            ? new Newtonsoft.Json.Linq.JObject()
                            : Newtonsoft.Json.Linq.JObject.Parse(respJson);

                        // nivel 3: respObj.content es otro string con el JSON final
                        var innerJson = respObj["content"]?.ToString();
                        var innerObj = string.IsNullOrEmpty(innerJson)
                            ? new Newtonsoft.Json.Linq.JObject()
                            : Newtonsoft.Json.Linq.JObject.Parse(innerJson);

                        // nivel 4: los datos están bajo "data"
                        franquicia = innerObj.SelectToken("data.franchise")?.ToString();
                        tipoCuenta = innerObj.SelectToken("data.accountType")?.ToString();
                        ultimos4 = innerObj.SelectToken("data.lastFourDigitsCard")?.ToString();
                        autorizationCode = innerObj.SelectToken("data.autorizationCode")?.ToString();
                    }

                    // 1️⃣ Insertar FormaPago y obtener ID
                    int idDetalleFormaPagoAuto;

                    using (var cmd = new SqlCommand())
                    {
                        cmd.Connection = conn;
                        cmd.Transaction = transaction;

                        cmd.CommandText = @"
                            INSERT INTO [FormaPago].[DetalleFormaPagoAutoServicio]
                            (
                                Fk_IdPosicion,
                                Valor,
                                Identificador,
                                Fk_IdTipoCompra,
                                Fk_IdFormaPago,
                                Fk_IdTurno,
                                Fk_IdPosicionProgramacion,
                                Fecha
                            )
                            VALUES
                            (
                                @IdPosicion,
                                @Valor,
                                @Identificador,
                                @IdTipoCompra,
                                @IdFormaPago,
                                @IdTurno,
                                @IdPreset,
                                @Fecha
                            );

                            SELECT SCOPE_IDENTITY();
                            ";

                        cmd.Parameters.AddWithValue("@IdPosicion", preset.IdPosicion);
                        cmd.Parameters.AddWithValue("@Valor", fp.Valor);
                        cmd.Parameters.AddWithValue("@IdTipoCompra", 1);
                        cmd.Parameters.AddWithValue("@IdFormaPago", fp.IdFormaPago);
                        cmd.Parameters.AddWithValue("@IdTurno", idTurno);
                        cmd.Parameters.AddWithValue("@IdPreset", idPreset);
                        cmd.Parameters.AddWithValue("@Fecha", DateTime.Now);
                        if (esQr)
                            cmd.Parameters.AddWithValue("@Identificador", fp.Identificador ?? (object)DBNull.Value);
                        else if (esTarjeta)
                            cmd.Parameters.AddWithValue("@Identificador", (object)autorizationCode ?? DBNull.Value);
                        else
                            cmd.Parameters.AddWithValue("@Identificador", "");

                        idDetalleFormaPagoAuto = Convert.ToInt32(cmd.ExecuteScalar());
                    }

                    if (esTarjeta && !string.IsNullOrEmpty(fp.Identificador))
                    {
                        //LogInfo($"Actualizando forma pago {JsonConvert.SerializeObject(response)}");

                        using var cmd = new SqlCommand();
                        cmd.Connection = conn;
                        cmd.Transaction = transaction;

                        cmd.CommandText = @"
                                            UPDATE [FormaPago].[DetalleFormaPagoAutoServicio]
                                            SET
                                                Franchise = @Franchise,
                                                AccountType = @AccountType,
                                                LastFourDigitsCard = @LastFour,
                                                OperatorType = @OperatorType
                                            WHERE Pk_IdFormaPagoAuto = @IdDetalleFormaPagoAuto";

                        cmd.Parameters.AddWithValue("@IdDetalleFormaPagoAuto", idDetalleFormaPagoAuto);
                        cmd.Parameters.AddWithValue("@Franchise", (object)franquicia ?? DBNull.Value);
                        cmd.Parameters.AddWithValue("@AccountType", (object)tipoCuenta ?? DBNull.Value);
                        cmd.Parameters.AddWithValue("@LastFour", (object)ultimos4 ?? DBNull.Value);
                        cmd.Parameters.AddWithValue("@OperatorType", (object)tipoOperacion ?? DBNull.Value);

                        cmd.ExecuteNonQuery();
                    }

                }

                transaction.Commit();
            }
            catch (Exception ex)
            {
                LogInfo( "Error insertando formas de pago " + ex.ToString());
                transaction.Rollback();
                throw;
            }
        }
        public void InsertarDetalleTransaccionAutoservicio(int idPreset, PresetRequest preset)
        {
            using var conn = _conexion.CrearConexion();
            conn.Open();
            int idFormaPago = 0;

            using var transaction = conn.BeginTransaction();

            try
            {
                foreach (var fp in preset.FormasPago)
                {
                    idFormaPago = ObtenerIdFormaPagoNSX(fp.IdFormaPago);
                    if (idFormaPago == 0)
                        throw new InvalidOperationException($"Forma de pago inválida. Id recibido: {fp.IdFormaPago}");
                    using var cmd = new SqlCommand();
                    cmd.Connection = conn;
                    cmd.Transaction = transaction;

                    cmd.CommandText = @"
                    INSERT INTO [FormaPago].[DetalleFormaPagoAutoServicio]
                    (
                        Fk_IdPosicion,
                        Valor,
                        Identificador,
                        Fk_IdTipoCompra,
                        Fk_IdFormaPago,
                        Fk_IdTurno,
                        Fk_IdPosicionProgramacion,
                        Fecha
                    )
                    VALUES
                    (
                        @IdPosicion,
                        @Valor,
                        @Identificador,
                        @IdTipoCompra,
                        @IdFormaPago,
                        @IdTurno,
                        @IdPreset,
                        @Fecha
                    )";

                    cmd.Parameters.AddWithValue("@IdPosicion", preset.IdPosicion);
                    cmd.Parameters.AddWithValue("@Valor", fp.Valor);
                    cmd.Parameters.AddWithValue("@Identificador", fp.Identificador ?? (object)DBNull.Value);
                    cmd.Parameters.AddWithValue("@IdTipoCompra", 1);
                    cmd.Parameters.AddWithValue("@IdFormaPago", idFormaPago);
                    cmd.Parameters.AddWithValue("@IdTurno", ObtenerIdTurnoByIdentificador(preset.Identificador));
                    cmd.Parameters.AddWithValue("@IdPreset", idPreset);
                    cmd.Parameters.AddWithValue("@Fecha", DateTime.Now);

                    cmd.ExecuteNonQuery();
                }

                transaction.Commit();
            }
            catch
            {
                transaction.Rollback();
                throw;
            }
        }

        public EstadoPresetModel ObtenerEstadoPreset(int idPreset)
        {
            using var conn = _conexion.CrearConexion();
            using var cmd = new SqlCommand();

            cmd.Connection = conn;
            cmd.CommandText = @"
                                SELECT 
                                    Fk_IdEstadoProgramacion,
                                    Fk_IdPosicion,
                                    Fk_IdVenta
                                FROM DispensadorPosicionProgramacion
                                WHERE Pk_IdDispensadorPosicionEstado = @IdPreset";

            cmd.Parameters.AddWithValue("@IdPreset", idPreset);

            conn.Open();

            using var dr = cmd.ExecuteReader();

            if (!dr.Read())
                return null; // 👈 importante

            return new EstadoPresetModel
            {
                Estado = (int)dr["Fk_IdEstadoProgramacion"],
                IdPosicion = (int)dr["Fk_IdPosicion"],
                IdVenta = dr["Fk_IdVenta"] != DBNull.Value ? (int)dr["Fk_IdVenta"] : 0,
                VentaZero = false // luego lo defines
            };
        }

        public VendedorModel ObtenerVendedorByDocumento(string documento)
        {
            using var conn = _conexion.CrearConexion();
            using var cmd = new SqlCommand();

            cmd.Connection = conn;
            cmd.CommandText = @"
                                SELECT
                                    Pk_IdIslero AS IdIslero,
                                    Cedula,
                                    Nombres AS Nombre,
                                    Apellidos,
                                    Activo
                                FROM [Turnos].[Islero]
                                WHERE Cedula = @Cedula";

            cmd.Parameters.AddWithValue("@Cedula", documento);

            conn.Open();

            using var dr = cmd.ExecuteReader();

            if (!dr.Read())
                return null;

            return new VendedorModel
            {
                IdIslero = Convert.ToInt32(dr["IdIslero"]),
                Cedula = dr["Cedula"]?.ToString(),
                Nombre = dr["Nombre"]?.ToString(),
                Apellidos = dr["Apellidos"]?.ToString(),
                Activo = Convert.ToBoolean(dr["Activo"])
            };
        }

        public VentaModel? ObtenerVentaById(int idVenta)
        {
            return EjecutarConsultaVenta(
                where: "v.Pk_IdVenta = @Id",
                addParams: cmd => cmd.Parameters.AddWithValue("@Id", idVenta));
        }

        public VentaModel? ObtenerVentaByIdPreset(int idPreset)
        {
            return EjecutarConsultaVenta(
                where: "pr.Pk_IdDispensadorPosicionEstado = @Id",
                addParams: cmd => cmd.Parameters.AddWithValue("@Id", idPreset));
        }

        public VentaModel? ObtenerUltimaVenta(int idDispensador, int cara)
        {
            return EjecutarConsultaVenta(
                where: "dp.Fk_IdDispensador = @IdDispensador AND dp.NumeroCaraDispensador = @Cara",
                addParams: cmd =>
                {
                    cmd.Parameters.AddWithValue("@IdDispensador", idDispensador);
                    cmd.Parameters.AddWithValue("@Cara", cara);
                },
                joinExtra: "INNER JOIN DispensadorPosicion dp ON dp.Pk_IdPosicion = dv.Fk_IdPosicion",
                top1: true,
                orderBy: "v.Pk_IdVenta DESC");
        }

        private VentaModel? EjecutarConsultaVenta(
            string where,
            Action<SqlCommand> addParams,
            string joinExtra = null,
            bool top1 = false,
            string orderBy = null)
        {
            string facturaJoin;
            string facturaCampo;
            if (_gne)
            {
                facturaJoin = "LEFT JOIN FElectronica.VentaFactura vf ON vf.IdVentaCombustible = v.Pk_IdVenta";
                facturaCampo = "vf.RespuestaFESAP AS FacturaElectronica";
            }
            else
            {
                facturaJoin = "LEFT JOIN FElectronica.VentaFactura vf ON vf.factura = v.Pk_IdVenta";
                facturaCampo = "vf.FacturaElectronica AS FacturaElectronica";
            }

            string top = top1 ? "TOP 1 " : "";
            string order = orderBy != null ? $"ORDER BY {orderBy}" : "";

            using var conn = _conexion.CrearConexion();
            using var cmd = new SqlCommand();
            cmd.Connection = conn;
            cmd.CommandText = $@"
                SELECT {top}
                    v.Pk_IdVenta IdVenta,
                    v.FechaFinal FechaVenta,
                    v.ValorTotal Dinero,
                    v.CantidadTotal Volumen,
                    dv.DineroInicial TotalDineroInicial,
                    dv.DineroFinal TotalDineroFinal,
                    dv.VolumenInicial TotalVolumenInicial,
                    dv.VolumenFinal TotalVolumenFinal,
                    pr.ValorProgramado,
                    pr.Fk_IdTipoProgramacion,
                    dv.Fk_IdPosicion IdPosicion,
                    pg.NumeroManguera,
                    pp.Precio PrecioVenta,
                    CASE WHEN pr.Pk_IdDispensadorPosicionEstado IS NULL THEN 0
                         ELSE pr.Pk_IdDispensadorPosicionEstado END IdProgramacion,
                    dv.Fk_IdProducto IdProducto,
                    v.Fk_IdTipoTransaccion TipoTransaccion,
                    {facturaCampo}
                FROM dbo.Venta v
                INNER JOIN DetalleVentaCombustible dv ON dv.Fk_IdVenta = v.Pk_IdVenta
                INNER JOIN PosicionGrado pg ON dv.Fk_IdPosicionGrado = pg.Pk_IdPosicionGrado
                INNER JOIN PrecioProducto pp ON dv.Fk_IdPrecioProducto = pp.Pk_IdPrecioProducto
                INNER JOIN DispensadorPosicionProgramacion pr ON pr.Fk_IdVenta = v.Pk_IdVenta
                {joinExtra}
                {facturaJoin}
                WHERE {where}
                {order}";

            addParams(cmd);

            conn.Open();
            using var dr = cmd.ExecuteReader();
            if (!dr.Read())
                return null;

            var venta = MapearVenta(dr);
            dr.Close();

            if (!_gne)
            {
                venta.FormasPago = ObtenerFormasPagoVenta(venta.IdVenta);
                venta.Fidelizacion = ObtenerFidelizacionVenta(venta.IdVenta);
                // Cuenta y vehiculo solo aplican a ventas con cliente (no efectivo)
                if (venta.TipoTransaccion != 1)
                    venta.Cliente = ObtenerClienteVenta(venta.IdVenta);
            }

            return venta;
        }

        private ClienteVentaModel? ObtenerClienteVenta(int idVenta)
        {
            using var conn = _conexion.CrearConexion();
            using var cmd = new SqlCommand(@"SELECT TOP 1 c.Nombre Cuenta, e.RazonSocial Empresa, pr.Placa, pr.Kilometraje
                                             FROM dbo.DispensadorPosicionProgramacion pr
                                             INNER JOIN dbo.Cuenta c ON c.Pk_IdCuenta = pr.Fk_IdCuenta
                                             LEFT JOIN dbo.Empresa e ON e.Pk_IdEmpresa = c.Fk_IdEmpresa
                                             WHERE pr.Fk_IdVenta = @IdVenta", conn);
            cmd.Parameters.AddWithValue("@IdVenta", idVenta);

            conn.Open();
            using var dr = cmd.ExecuteReader();
            if (!dr.Read())
                return null;

            return new ClienteVentaModel
            {
                Cuenta = dr["Cuenta"] as string,
                Empresa = dr["Empresa"] as string,
                Placa = dr["Placa"] as string,
                Kilometraje = dr["Kilometraje"] == DBNull.Value ? null : (double?)Convert.ToDouble(dr["Kilometraje"])
            };
        }

        // Formas de pago registradas de la venta; sin filas la venta es efectivo
        private List<FormaPagoRegistradaModel> ObtenerFormasPagoVenta(int idVenta)
        {
            var formasPago = new List<FormaPagoRegistradaModel>();

            using var conn = _conexion.CrearConexion();
            using var cmd = new SqlCommand(@"SELECT d.Fk_IdFormaPago, f.Descripcion, d.Valor, d.Identificador
                                             FROM FormaPago.DetalleFormaPago d
                                             INNER JOIN FormaPago.FormaPago f ON f.Pk_IdFormaPago = d.Fk_IdFormaPago
                                             WHERE d.ConsecutivoReferenciaTabla = @IdVenta AND d.Fk_IdTipoCompra = 1 AND d.Activa = 1
                                             ORDER BY d.Pk_IdDetalleFormaPago", conn);
            cmd.Parameters.AddWithValue("@IdVenta", idVenta);

            conn.Open();
            using var dr = cmd.ExecuteReader();
            while (dr.Read())
            {
                formasPago.Add(new FormaPagoRegistradaModel
                {
                    IdFormaPago = Convert.ToInt32(dr["Fk_IdFormaPago"]),
                    Nombre = dr["Descripcion"]?.ToString(),
                    Valor = Convert.ToDouble(dr["Valor"]),
                    Identificador = dr["Identificador"] == DBNull.Value ? null : dr["Identificador"].ToString()
                });
            }

            return formasPago;
        }

        // Acumulacion de fidelidad de la venta (cualquier programa): operacion tipo Acumulacion, estado cerrado y sin error
        private FidelizacionVentaModel ObtenerFidelizacionVenta(int idVenta)
        {
            var fidelizacion = new FidelizacionVentaModel();

            using var conn = _conexion.CrearConexion();
            conn.Open();

            // Fk_IdFidelidad no existe en todas las bases (la de Prime no la trae): sin ella no se sabe el programa
            bool hayPrograma;
            using (var cmdCol = new SqlCommand("SELECT CASE WHEN COL_LENGTH('Fidelidad.VentaFidelizada','Fk_IdFidelidad') IS NOT NULL THEN 1 ELSE 0 END", conn))
                hayPrograma = Convert.ToInt32(cmdCol.ExecuteScalar()) == 1;

            using var cmd = new SqlCommand($@"SELECT TOP 1 Fecha, NumDocumento, NombreCliente, MillasPuntosAcumulados, {(hayPrograma ? "Fk_IdFidelidad" : "CAST(NULL AS int) AS Fk_IdFidelidad")}
                                             FROM Fidelidad.VentaFidelizada
                                             WHERE Fk_IdVenta = @IdVenta AND Fk_IdTipoTransaccion = 1 AND Fk_IdEstadoTransaccion = 2
                                               AND (CodigoError IS NULL OR CodigoError = '')
                                             ORDER BY Pk_IdFidelizacion DESC", conn);
            cmd.Parameters.AddWithValue("@IdVenta", idVenta);

            using var dr = cmd.ExecuteReader();
            if (dr.Read())
            {
                fidelizacion.Acumulo = true;
                fidelizacion.Fecha = dr["Fecha"] == DBNull.Value ? null : (DateTime?)dr["Fecha"];
                fidelizacion.IdFidelidad = dr["Fk_IdFidelidad"] == DBNull.Value ? null : (int?)Convert.ToInt32(dr["Fk_IdFidelidad"]);
                fidelizacion.Programa = fidelizacion.IdFidelidad switch
                {
                    1 => "PuntosColombia",
                    2 => "ViveTerpel",
                    3 => "Commodo",
                    4 => "Local",
                    5 => "Leal",
                    _ => null
                };
                fidelizacion.Documento = dr["NumDocumento"] as string;
                fidelizacion.Nombre = dr["NombreCliente"] as string;
                fidelizacion.Acumulado = dr["MillasPuntosAcumulados"] == DBNull.Value ? null : (double?)Convert.ToDouble(dr["MillasPuntosAcumulados"]);
            }

            return fidelizacion;
        }

        private VentaModel MapearVenta(SqlDataReader dr)
        {
            var venta = new VentaModel
            {
                IdVenta = (int)dr["IdVenta"],
                FechaVenta = (DateTime)dr["FechaVenta"],
                Dinero = Convert.ToDouble(dr["Dinero"]),
                Volumen = Convert.ToDouble(dr["Volumen"]),
                TotalDineroInicial = Convert.ToDouble(dr["TotalDineroInicial"]),
                TotalDineroFinal = Convert.ToDouble(dr["TotalDineroFinal"]),
                TotalVolumenInicial = Convert.ToDouble(dr["TotalVolumenInicial"]),
                TotalVolumenFinal = Convert.ToDouble(dr["TotalVolumenFinal"]),
                ValorProgramado = Convert.ToDouble(dr["ValorProgramado"]),
                TipoProgramacion = (int)dr["Fk_IdTipoProgramacion"],
                IdPosicion = (int)dr["IdPosicion"],
                NumeroManguera = (int)dr["NumeroManguera"],
                PrecioVenta = Convert.ToDouble(dr["PrecioVenta"]),
                IdProgramacion = (int)dr["IdProgramacion"],
                IdProducto = (int)dr["IdProducto"],
                TipoTransaccion = (int)dr["TipoTransaccion"],
                FElectronica = dr["FacturaElectronica"] as string
            };

            if (_gne)
            {
                venta.FElectronica = ObtenerNumeroFacturaGne(venta.FElectronica);
            }

            // Transaccion 1: no maneja vuelto
            if (venta.TipoTransaccion != 1)
            {
                venta.Vuelto = (int)Math.Round(venta.TipoProgramacion switch
                {
                    2 => venta.ValorProgramado - venta.Dinero,
                    3 => (venta.ValorProgramado * venta.PrecioVenta) - venta.Dinero,
                    _ => 0
                }, MidpointRounding.AwayFromZero);

                var vuelto = ObtenerVueltoByIdPreset(venta.IdProgramacion);
                venta.VueltoRegistrado = vuelto != null;
            }

            return venta;
        }
        //public VentaModel ObtenerVentaById(int idVenta)
        //{
        //    using var conn = _conexion.CrearConexion();
        //    using var cmd = new SqlCommand();

        //    cmd.Connection = conn;

        //    string facturaJoin;
        //    string facturaCampo;

        //    if (_gne)
        //    {
        //        facturaJoin = "LEFT JOIN FElectronica.VentaFactura vf on vf.IdVentaCombustible = v.Pk_IdVenta";
        //        facturaCampo = "vf.RespuestaFESAP AS FacturaElectronica";
        //    }
        //    else
        //    {
        //        facturaJoin = "LEFT JOIN FElectronica.VentaFactura vf on vf.factura = v.Pk_IdVenta";
        //        facturaCampo = "vf.FacturaElectronica AS FacturaElectronica";
        //    }

        //    cmd.CommandText = $@"
        //        SELECT
        //            v.Pk_IdVenta IdVenta,
        //            v.FechaFinal FechaVenta,
        //            v.ValorTotal Dinero,
        //            v.CantidadTotal Volumen,
        //            dv.DineroInicial TotalDineroInicial,
        //            dv.DineroFinal TotalDineroFinal,
        //            dv.VolumenInicial TotalVolumenInicial,
        //            dv.VolumenFinal TotalVolumenFinal,
        //            pr.ValorProgramado,
        //            pr.Fk_IdTipoProgramacion,
        //            dv.Fk_IdPosicion IdPosicion,
        //            pg.NumeroManguera,
        //            pp.Precio PrecioVenta,
        //            CASE
        //                WHEN pr.Pk_IdDispensadorPosicionEstado IS NULL THEN 0
        //                ELSE pr.Pk_IdDispensadorPosicionEstado
        //            END IdProgramacion,
        //            dv.Fk_IdProducto IdProducto,
        //            v.Fk_IdTipoTransaccion TipoTransaccion,
        //            {facturaCampo}
        //        FROM dbo.Venta v
        //        INNER JOIN DetalleVentaCombustible dv ON dv.Fk_IdVenta = v.Pk_IdVenta
        //        INNER JOIN PosicionGrado pg ON dv.Fk_IdPosicionGrado = pg.Pk_IdPosicionGrado
        //        INNER JOIN PrecioProducto pp ON dv.Fk_IdPrecioProducto = pp.Pk_IdPrecioProducto
        //        INNER JOIN DispensadorPosicionProgramacion pr ON pr.Fk_IdVenta = v.Pk_IdVenta
        //        {facturaJoin}
        //        WHERE v.Pk_IdVenta = @IdVenta";

        //    cmd.Parameters.AddWithValue("@IdVenta", idVenta);

        //    conn.Open();

        //    using var dr = cmd.ExecuteReader();

        //    if (!dr.Read())
        //        return null;

        //    var venta = new VentaModel
        //    {
        //        IdVenta = (int)dr["IdVenta"],
        //        FechaVenta = (DateTime)dr["FechaVenta"],
        //        Dinero = Convert.ToDouble(dr["Dinero"]),
        //        Volumen = Convert.ToDouble(dr["Volumen"]),
        //        TotalDineroInicial = Convert.ToDouble(dr["TotalDineroInicial"]),
        //        TotalDineroFinal = Convert.ToDouble(dr["TotalDineroFinal"]),
        //        TotalVolumenInicial = Convert.ToDouble(dr["TotalVolumenInicial"]),
        //        TotalVolumenFinal = Convert.ToDouble(dr["TotalVolumenFinal"]),
        //        ValorProgramado = Convert.ToDouble(dr["ValorProgramado"]),
        //        TipoProgramacion = (int)dr["Fk_IdTipoProgramacion"],
        //        IdPosicion = (int)dr["IdPosicion"],
        //        NumeroManguera = (int)dr["NumeroManguera"],
        //        PrecioVenta = Convert.ToDouble(dr["PrecioVenta"]),
        //        IdProgramacion = (int)dr["IdProgramacion"],
        //        IdProducto = (int)dr["IdProducto"],
        //        TipoTransaccion = (int)dr["TipoTransaccion"],
        //        FElectronica = dr["FacturaElectronica"] as string
        //    };

        //    if (_gne)
        //    {
        //        venta.FElectronica = ObtenerNumeroFacturaGne(venta.FElectronica);
        //    }

        //    venta.Vuelto = (int)Math.Round(venta.TipoProgramacion switch
        //    {
        //        2 => venta.ValorProgramado - venta.Dinero,
        //        3 => (venta.ValorProgramado * venta.PrecioVenta) - venta.Dinero,
        //        _ => 0
        //    }, MidpointRounding.AwayFromZero);

        //    var vuelto = ObtenerVueltoByIdPreset(venta.IdProgramacion);

        //    venta.VueltoRegistrado = vuelto != null;

        //    return venta;
        //}

        private string ObtenerNumeroFacturaGne(string respuestaFesap)
        {
            if (string.IsNullOrWhiteSpace(respuestaFesap))
                return null;

            try
            {
                dynamic json = JsonConvert.DeserializeObject(respuestaFesap);

                if (json?.Prefijo_Fact == null || json?.No_Fact_DIAN == null)
                    return null;

                return $"{json.Prefijo_Fact}{json.No_Fact_DIAN}";
            }
            catch
            {
                return null;
            }
        }
        //public VentaModel? ObtenerVentaByIdPreset(int idPreset)
        //{
        //    using var conn = _conexion.CrearConexion();
        //    using var cmd = new SqlCommand();

        //    cmd.Connection = conn;
        //    cmd.CommandText = @"SELECT
        //                            v.Pk_IdVenta AS IdVenta, v.FechaFinal AS FechaVenta, v.ValorTotal AS Dinero,
        //                            v.CantidadTotal AS Volumen, dv.DineroInicial AS TotalDineroInicial, dv.DineroFinal AS TotalDineroFinal,
        //                            dv.VolumenInicial AS TotalVolumenInicial, dv.VolumenFinal AS TotalVolumenFinal, pr.ValorProgramado, pr.Fk_IdTipoProgramacion,
        //                            dv.Fk_IdPosicion AS IdPosicion, pg.NumeroManguera, pp.Precio AS PrecioVenta, ISNULL(pr.Pk_IdDispensadorPosicionEstado, 0) AS IdProgramacion,
        //                            dv.Fk_IdProducto AS IdProducto, v.Fk_IdTipoTransaccion AS TipoTransaccion, vf.FacturaElectronica
        //                        FROM dbo.Venta v
        //                        INNER JOIN DetalleVentaCombustible dv
        //                            ON dv.Fk_IdVenta = v.Pk_IdVenta
        //                        INNER JOIN PosicionGrado pg
        //                            ON dv.Fk_IdPosicionGrado = pg.Pk_IdPosicionGrado
        //                        INNER JOIN PrecioProducto pp
        //                            ON dv.Fk_IdPrecioProducto = pp.Pk_IdPrecioProducto
        //                        INNER JOIN DispensadorPosicionProgramacion pr
        //                            ON pr.Fk_IdVenta = v.Pk_IdVenta
        //                        LEFT JOIN FElectronica.VentaFactura vf
        //                            ON vf.factura = v.Pk_IdVenta
        //                        WHERE pr.Pk_IdDispensadorPosicionEstado = @IdPreset";

        //    cmd.Parameters.AddWithValue("@IdPreset", idPreset);

        //    conn.Open();

        //    using var dr = cmd.ExecuteReader();

        //    if (!dr.Read())
        //        return null;

        //    var venta = new VentaModel
        //    {
        //        IdVenta = (int)dr["IdVenta"],
        //        FechaVenta = (DateTime)dr["FechaVenta"],
        //        Dinero = Convert.ToDouble(dr["Dinero"]),
        //        Volumen = Convert.ToDouble(dr["Volumen"]),
        //        TotalDineroInicial = Convert.ToDouble(dr["TotalDineroInicial"]),
        //        TotalDineroFinal = Convert.ToDouble(dr["TotalDineroFinal"]),
        //        TotalVolumenInicial = Convert.ToDouble(dr["TotalVolumenInicial"]),
        //        TotalVolumenFinal = Convert.ToDouble(dr["TotalVolumenFinal"]),
        //        ValorProgramado = Convert.ToDouble(dr["ValorProgramado"]),
        //        TipoProgramacion = (int)dr["Fk_IdTipoProgramacion"],
        //        IdPosicion = (int)dr["IdPosicion"],
        //        NumeroManguera = (int)dr["NumeroManguera"],
        //        PrecioVenta = Convert.ToDouble(dr["PrecioVenta"]),
        //        IdProgramacion = (int)dr["IdProgramacion"],
        //        IdProducto = (int)dr["IdProducto"],
        //        TipoTransaccion = (int)dr["TipoTransaccion"],
        //        FElectronica = dr["FacturaElectronica"] as string
        //    };

        //    venta.Vuelto = (int)Math.Round(
        //        venta.TipoProgramacion switch
        //        {
        //            2 => venta.ValorProgramado - venta.Dinero,
        //            3 => (venta.ValorProgramado * venta.PrecioVenta) - venta.Dinero,
        //            _ => 0
        //        },
        //        MidpointRounding.AwayFromZero);

        //    var vuelto = ObtenerVueltoByIdPreset(venta.IdProgramacion);

        //    venta.VueltoRegistrado = vuelto != null;

        //    return venta;
        //}

        //public VentaModel ObtenerUltimaVenta(int idDispensador, int cara)
        //{
        //    using var conn = _conexion.CrearConexion();
        //    using var cmd = new SqlCommand();

        //    cmd.Connection = conn;
        //    cmd.CommandText = @"SELECT TOP 1 v.Pk_IdVenta IdVenta,v.FechaFinal FechaVenta,v.ValorTotal Dinero,v.CantidadTotal Volumen, 
        //                            dv.DineroInicial TotalDineroInicial,dv.DineroFinal TotalDineroFinal, 
        //                            dv.VolumenInicial TotalVolumenInicial,dv.VolumenFinal TotalVolumenFinal, 
		      //                      pr.ValorProgramado, pr.Fk_IdTipoProgramacion,
        //                            dv.Fk_IdPosicion IdPosicion,pg.NumeroManguera,pp.Precio PrecioVenta,
	       //                         CASE WHEN pr.Pk_IdDispensadorPosicionEstado is null THEN 0 ELSE pr.Pk_IdDispensadorPosicionEstado END IdProgramacion, 
        //                            dv.Fk_IdProducto IdProducto, v.Fk_IdTipoTransaccion TipoTransaccion, vf.FacturaElectronica
        //                        FROM [dbo].[Venta] v
	       //                     INNER JOIN DetalleVentaCombustible dv on dv.Fk_IdVenta = v.Pk_IdVenta
	       //                     INNER JOIN PosicionGrado pg on dv.Fk_IdPosicionGrado = pg.Pk_IdPosicionGrado
	       //                     INNER JOIN PrecioProducto pp on dv.Fk_IdPrecioProducto = pp.Pk_IdPrecioProducto
	       //                     INNER JOIN DispensadorPosicionProgramacion pr on pr.Fk_IdVenta = v.Pk_IdVenta
        //                        INNER JOIN DispensadorPosicion dp on dp.Pk_IdPosicion = dv.Fk_IdPosicion
        //                        LEFT JOIN FElectronica.VentaFactura vf on vf.factura = v.Pk_IdVenta
        //                        WHERE dp.Fk_IdDispensador = @IdDispensador AND dp.NumeroCaraDispensador = @Cara
        //                        ORDER BY 1 DESC";

        //    cmd.Parameters.AddWithValue("@IdDispensador", idDispensador);
        //    cmd.Parameters.AddWithValue("@Cara", cara);

        //    conn.Open();

        //    using var dr = cmd.ExecuteReader();

        //    if (!dr.Read())
        //        return null; // 👈 importante

        //    var venta = new VentaModel
        //    {
        //        IdVenta = (int)dr["IdVenta"],
        //        FechaVenta = (DateTime)dr["FechaVenta"],
        //        Dinero = Convert.ToDouble(dr["Dinero"]),
        //        Volumen = Convert.ToDouble(dr["Volumen"]),
        //        TotalDineroInicial = Convert.ToDouble(dr["TotalDineroInicial"]),
        //        TotalDineroFinal = Convert.ToDouble(dr["TotalDineroFinal"]),
        //        TotalVolumenInicial = Convert.ToDouble(dr["TotalVolumenInicial"]),
        //        TotalVolumenFinal = Convert.ToDouble(dr["TotalVolumenFinal"]),
        //        ValorProgramado = Convert.ToDouble(dr["ValorProgramado"]),
        //        TipoProgramacion = (int)dr["Fk_IdTipoProgramacion"],
        //        IdPosicion = (int)dr["IdPosicion"],
        //        NumeroManguera = (int)dr["NumeroManguera"],
        //        PrecioVenta = Convert.ToDouble(dr["PrecioVenta"]),
        //        IdProgramacion = (int)dr["IdProgramacion"],
        //        IdProducto = (int)dr["IdProducto"],
        //        TipoTransaccion = (int)dr["TipoTransaccion"],
        //        FElectronica = dr["FacturaElectronica"] as string
        //    };

        //    venta.Vuelto = (int)Math.Round(venta.TipoProgramacion switch
        //    {
        //        2 => venta.ValorProgramado - venta.Dinero,
        //        3 => (venta.ValorProgramado * venta.PrecioVenta) - venta.Dinero,
        //        _ => 0
        //    }, MidpointRounding.AwayFromZero);

        //    var vuelto = ObtenerVueltoByIdPreset(venta.IdProgramacion);

        //    venta.VueltoRegistrado = vuelto != null;

        //    return venta;
        //}

        public VentaModel ObtenerVentaByIdGne(int idVenta)
        {
            using var conn = _conexion.CrearConexion();
            using var cmd = new SqlCommand();

            cmd.Connection = conn;
            cmd.CommandText = @"SELECT v.Pk_IdVenta IdVenta,v.FechaFinal FechaVenta,v.ValorTotal Dinero,v.CantidadTotal Volumen, 
                             dv.DineroInicial TotalDineroInicial,dv.DineroFinal TotalDineroFinal, 
                             dv.VolumenInicial TotalVolumenInicial,dv.VolumenFinal TotalVolumenFinal, 
	                            pr.ValorProgramado, pr.Fk_IdTipoProgramacion,
                             dv.Fk_IdPosicion IdPosicion,pg.NumeroManguera,pp.Precio PrecioVenta,
                             CASE WHEN pr.Pk_IdDispensadorPosicionEstado is null THEN 0 ELSE pr.Pk_IdDispensadorPosicionEstado END IdProgramacion, 
                             dv.Fk_IdProducto IdProducto, v.Fk_IdTipoTransaccion TipoTransaccion, vf.RespuestaFESAP
                         FROM [dbo].[Venta] v
                         INNER JOIN DetalleVentaCombustible dv on dv.Fk_IdVenta = v.Pk_IdVenta
                         INNER JOIN PosicionGrado pg on dv.Fk_IdPosicionGrado = pg.Pk_IdPosicionGrado
                         INNER JOIN PrecioProducto pp on dv.Fk_IdPrecioProducto = pp.Pk_IdPrecioProducto
                         INNER JOIN DispensadorPosicionProgramacion pr on pr.Fk_IdVenta = v.Pk_IdVenta
                         LEFT JOIN FElectronica.VentaFactura vf on vf.IdVentaCombustible = v.Pk_IdVenta
                         WHERE v.Pk_IdVenta  = @IdVenta";

            cmd.Parameters.AddWithValue("@IdVenta", idVenta);

            conn.Open();

            using var dr = cmd.ExecuteReader();

            if (!dr.Read())
                return null; // 👈 importante

            var venta = new VentaModel
            {
                IdVenta = (int)dr["IdVenta"],
                FechaVenta = (DateTime)dr["FechaVenta"],
                Dinero = Convert.ToDouble(dr["Dinero"]),
                Volumen = Convert.ToDouble(dr["Volumen"]),
                TotalDineroInicial = Convert.ToDouble(dr["TotalDineroInicial"]),
                TotalDineroFinal = Convert.ToDouble(dr["TotalDineroFinal"]),
                TotalVolumenInicial = Convert.ToDouble(dr["TotalVolumenInicial"]),
                TotalVolumenFinal = Convert.ToDouble(dr["TotalVolumenFinal"]),
                ValorProgramado = Convert.ToDouble(dr["ValorProgramado"]),
                TipoProgramacion = (int)dr["Fk_IdTipoProgramacion"],
                IdPosicion = (int)dr["IdPosicion"],
                NumeroManguera = (int)dr["NumeroManguera"],
                PrecioVenta = Convert.ToDouble(dr["PrecioVenta"]),
                IdProgramacion = (int)dr["IdProgramacion"],
                IdProducto = (int)dr["IdProducto"],
                TipoTransaccion = (int)dr["TipoTransaccion"],
                FElectronica = dr["RespuestaFESAP"] as string
            };

            // Transaccion 1: no maneja vuelto
            if (venta.TipoTransaccion != 1)
            {
                venta.Vuelto = (int)Math.Round(venta.TipoProgramacion switch
                {
                    2 => venta.ValorProgramado - venta.Dinero,
                    3 => (venta.ValorProgramado * venta.PrecioVenta) - venta.Dinero,
                    _ => 0
                }, MidpointRounding.AwayFromZero);

                var vuelto = ObtenerVueltoByIdPreset(venta.IdProgramacion);

                venta.VueltoRegistrado = vuelto != null;
            }

            return venta;
        }
        public List<ProductoModel> ObtenerPrecios()
        {
            var precios = new List<ProductoModel>();

            using var conn = _conexion.CrearConexion();
            using var cmd = new SqlCommand();

            cmd.Connection = conn;
            cmd.CommandText = @"SELECT 
                            P.Pk_IdProducto AS IdProducto, 
                            P.Nombre, 
                            PP.Precio,
                            UM.UnidadMedida
                        FROM Producto P
                        INNER JOIN Nivel N 
                            ON N.Nombre = 'Autoservicio'
                        INNER JOIN PrecioProducto PP 
                            ON PP.Fk_IdProducto = P.Pk_IdProducto 
                           AND PP.Fk_IdNivel = N.Pk_IdNivel
                        INNER JOIN UnidadMedida UM
                            ON P.Fk_IdUnidadMedida = UM.Pk_IdUnidadMedida
                        WHERE PP.Activo = 1";

            try
            {
                conn.Open();

                using var dr = cmd.ExecuteReader();

                while (dr.Read())
                {
                    var idProducto = (int)dr["IdProducto"];

                    // 🔹 Obtener recurso
                    var maxPresetStr = ObtenerRecurso("MaximoPreset", "Producto", idProducto);

                    decimal? maxPreset = decimal.TryParse(
                        maxPresetStr?.Replace(',', '.'),
                        NumberStyles.Any,
                        CultureInfo.InvariantCulture,
                        out var val
                    ) ? val : null;

                    // 🔹 Crear objeto
                    precios.Add(new ProductoModel
                    {
                        IdProducto = idProducto,
                        NombreProducto = dr["Nombre"].ToString(),
                        Precio = Convert.ToDecimal(dr["Precio"]),
                        UnidadMedida = dr["UnidadMedida"].ToString(),
                        MaximoPreset = maxPreset
                    });
                }
            }
            catch (Exception)
            {
                throw;
            }

            return precios;
        }

        public string ObtenerConfiguracionAutoservice(string nombre)
        {
            string valor = "";

            using var conn = _conexion.CrearConexion();

            using var co = new SqlCommand();
            co.Connection = conn;

            try
            {
                co.CommandText = @$"SELECT Valor FROM [Autoservice].[Configuracion]
                                    WHERE Nombre = '{nombre}'";


                conn.Open();
                using SqlDataReader dr = co.ExecuteReader();

                while (dr.Read())
                {
                    valor = (string)dr["Valor"];
                }
            }
            catch (Exception)
            {
                throw;
            }
            finally
            {
                conn.Close();
            }

            return valor;
        }

        public ClienteFEModel ConsultarClienteFE(string documento)
        {
            using var conn = _conexion.CrearConexion();
            using var cmd = new SqlCommand();

            cmd.Connection = conn;
            cmd.CommandText = @"SELECT [RazonSocial],[TipoPersona],[TipoDocumento],[Documento],[DV],
                                        [Telefono],[Email],[ResponsabilidadFiscal],[Direccion],[Departamento],[Municipio],[RegimenFiscal]
                                       FROM [FElectronica].[ClienteFE] WHERE [Documento] = @Documento";

            cmd.Parameters.AddWithValue("@Documento", documento);

            conn.Open();

            using var dr = cmd.ExecuteReader();

            if (!dr.Read())
                return null; // 👈 importante

            return new ClienteFEModel
            {
                RazonSocial = dr["RazonSocial"] as string,
                TipoPersona = dr["TipoPersona"] as string,
                TipoDocumento = dr["TipoDocumento"] as string,
                Documento = dr["Documento"] as string,
                DV = dr["DV"] as string,
                Telefono = dr["Telefono"] as string,
                Email = dr["Email"] as string,
                ResponsabilidadFiscal = dr["ResponsabilidadFiscal"] as string,
                Direccion = dr["Direccion"] as string,
                Departamento = dr["Departamento"] as string,
                Municipio = dr["Municipio"] as string,
                RegimenFiscal = dr["RegimenFiscal"] as string,
            };
        }

        public ClienteFEModel ConsultarClienteFEGNE(string documento)
        {
            using var conn = _conexion.CrearConexion();
            using var cmd = new SqlCommand();

            cmd.Connection = conn;
            cmd.CommandText = @"SELECT [Nombre],[TipoCliente],[TipoDoc],[Documento],[Correo]
                                       FROM [FElectronica].[Clientes] WHERE [Documento] = @Documento";

            cmd.Parameters.AddWithValue("@Documento", documento);

            conn.Open();

            using var dr = cmd.ExecuteReader();

            if (!dr.Read())
                return null; // 👈 importante

            return new ClienteFEModel
            {
                RazonSocial = dr["Nombre"] as string,
                TipoPersona = dr["TipoCliente"] as string,
                TipoDocumento = dr["TipoDoc"] as string,
                Documento = documento,
                DV = "",
                Telefono = "",
                Email = dr["Correo"] as string,
                ResponsabilidadFiscal = "",
                Direccion = "",
                Departamento = "",
                Municipio = "",
                RegimenFiscal = "",
            };
        }

        public TipoDocumentoDianModel ObtenerDocumentoDian(int? tipodocumento)
        {
            using var conn = _conexion.CrearConexion();
            using var cmd = new SqlCommand();

            cmd.Connection = conn;
            cmd.CommandText = @"SELECT [CodDocDian],[NombreDocDian]
                                       FROM [dbo].[TipoDocumentoDian]
                                WHERE [CodDocDian] = @Documento";

            cmd.Parameters.AddWithValue("@Documento", tipodocumento);

            conn.Open();

            using var dr = cmd.ExecuteReader();

            if (!dr.Read())
                return null; // 👈 importante

            return new TipoDocumentoDianModel
            {
                CodDocDian = (int)dr["CodDocDian"],
                NombreDocDian = dr["NombreDocDian"] as string,
            };
        }

        public bool InsertarVentaFactura(FacturacionRequest Factura)
        {
            using var conn = _conexion.CrearConexion();
            conn.Open();
            using var transaction = conn.BeginTransaction();
            var docDian = ObtenerDocumentoDian(Factura.TipoDocumento);
            try
            {
                using var cmd = new SqlCommand();
                cmd.Connection = conn;
                cmd.Transaction = transaction;

                cmd.CommandText = @"INSERT INTO [FElectronica].[VentaFactura]
                                           ([Factura]
                                           ,[RazonSocial]
                                           ,[TipoPersona]
                                           ,[TipoDocumento]
                                           ,[Documento]
                                           ,[Email]
                                           ,[ResponsabilidadFiscal]
                                           ,[Fecha]
                                           ,[Sincronizado]
                                           ,[Fk_IdFactura])
                                     VALUES
                                           (
                                   @Factura,
                                   @RazonSocial,
                                   @TipoPersona,
                                   @TipoDocumento,
                                   @Documento,
                                   @Email,
                                   @ResponsabilidadFiscal,
                                   @Fecha,
                                   @Sincronizado,
                                   @Fk_IdFactura)";

                cmd.Parameters.AddWithValue("@Factura", Factura.IdVenta);
                cmd.Parameters.AddWithValue("@RazonSocial", Factura.RazonSocial);
                cmd.Parameters.AddWithValue("@TipoPersona", "");
                cmd.Parameters.AddWithValue("@TipoDocumento", docDian.NombreDocDian);
                cmd.Parameters.AddWithValue("@Documento", Factura.Documento);
                cmd.Parameters.AddWithValue("@Email", Factura.Email);
                cmd.Parameters.AddWithValue("@ResponsabilidadFiscal", "");
                cmd.Parameters.AddWithValue("@Fecha", DateTime.Now);
                cmd.Parameters.AddWithValue("@Sincronizado", false);
                cmd.Parameters.AddWithValue("@Fk_IdFactura", 0);

                cmd.ExecuteNonQuery();

                transaction.Commit();
                return true;
            }
            catch (Exception)
            {
                transaction.Rollback();
                throw;
            }
        }

        public bool InsertarVentaFacturaGNE(FacturacionRequest Factura)
        {
            using var conn = _conexion.CrearConexion();
            conn.Open();
            using var transaction = conn.BeginTransaction();
            try
            {
                string numeroFactura = null;

                using (var cmdDetalle = new SqlCommand())
                {
                    cmdDetalle.Connection = conn;
                    cmdDetalle.Transaction = transaction;
                    cmdDetalle.CommandText = @"SELECT TOP 1 NumeroFactura
                                       FROM [dbo].[FacturaDetalle]
                                       WHERE IdVentaCombustible = @IdVenta
                                       ORDER BY Pk_IdDetalleFactura DESC";
                    cmdDetalle.Parameters.AddWithValue("@IdVenta", Factura.IdVenta);

                    using var drDetalle = cmdDetalle.ExecuteReader();
                    if (drDetalle.Read())
                        numeroFactura = drDetalle["NumeroFactura"]?.ToString();
                }

                using var cmd = new SqlCommand();
                cmd.Connection = conn;
                cmd.Transaction = transaction;
                cmd.CommandText = @"INSERT INTO [FElectronica].[VentaFactura]
                                   ([FechaSolicitud]
                                   ,[Factura]
                                   ,[Documento]
                                   ,[IdVentaCombustible]
                                   ,[IdVentaCanasta]
                                   ,[IntentosSAP] 
                                   ,[SincronizadoSAP]
                                   ,[SincronizadoFESAP]
                                   ,[IntentosFESAP])
                             VALUES
                                   (@FechaSolicitud,
                                    @Factura,
                                    @Documento,
                                    @IdVentaCombustible,
                                    @IdVentaCanasta,
                                    @IntentosSAP,
                                    @SincronizadoSAP,
                                    @SincronizadoFESAP,
                                    @IntentosFESAP)";

                cmd.Parameters.AddWithValue("@FechaSolicitud", DateTime.Now);
                cmd.Parameters.AddWithValue("@Factura", (object)numeroFactura ?? DBNull.Value);
                cmd.Parameters.AddWithValue("@Documento", Factura.Documento);
                cmd.Parameters.AddWithValue("@IdVentaCombustible", Factura.IdVenta);
                cmd.Parameters.AddWithValue("@IdVentaCanasta", 0);
                cmd.Parameters.AddWithValue("@IntentosSAP", 0);
                cmd.Parameters.AddWithValue("@SincronizadoSAP", false);
                cmd.Parameters.AddWithValue("@SincronizadoFESAP", false);
                cmd.Parameters.AddWithValue("@IntentosFESAP", 0);

                cmd.ExecuteNonQuery();
                transaction.Commit();
                return true;
            }
            catch (Exception)
            {
                transaction.Rollback();
                throw;
            }
        }

        public VentaFacturaModel ValidarFEByIdVenta(int idVenta)
        {
            using var conn = _conexion.CrearConexion();
            using var cmd = new SqlCommand();
            try
            {
                cmd.Connection = conn;

                cmd.CommandText = @"SELECT Factura, Sincronizado, FacturaElectronica
                                    FROM [FElectronica].[VentaFactura]
                                    WHERE Factura = @Factura AND Fk_IdFactura = 0";

                cmd.Parameters.AddWithValue("@Factura", idVenta);

                conn.Open();

                using var dr = cmd.ExecuteReader();

                if (!dr.Read())
                    return null;

                return new VentaFacturaModel
                {
                    idVenta = (int)dr["Factura"],
                    FacturaElectronica = (string)dr["FacturaElectronica"],
                    Sincronizado = (bool)dr["Sincronizado"],
                };
            }
            catch (Exception ex)
            {
                return null;
            }
        }

        public VentaFacturaModel ValidarFEByIdVentaGNE(int idVenta)
        {
            using var conn = _conexion.CrearConexion();
            using var cmd = new SqlCommand();
            try
            {
                cmd.Connection = conn;
                cmd.CommandText = @"SELECT IdVentaCombustible, SincronizadoSAP, RespuestaFESAP
                            FROM [FElectronica].[VentaFactura]
                            WHERE IdVentaCombustible = @IdVenta";
                cmd.Parameters.AddWithValue("@IdVenta", idVenta);
                conn.Open();
                using var dr = cmd.ExecuteReader();
                if (!dr.Read())
                    return null;

                var respuestaJson = dr["RespuestaFESAP"] as string;
                var sincronizado = (bool)dr["SincronizadoSAP"];
                string facturaElectronica = "Procesando...";

                if (!string.IsNullOrWhiteSpace(respuestaJson))
                {
                    try
                    {
                        var json = JsonDocument.Parse(respuestaJson).RootElement;
                        if (json.TryGetProperty("Prefijo_Fact", out var prefijo) &&
                            json.TryGetProperty("No_Fact_DIAN", out var noFact))
                        {
                            string noFactSinCero = noFact.ValueKind switch
                            {
                                JsonValueKind.Number => noFact.GetInt64().ToString(),
                                JsonValueKind.String => int.Parse(noFact.GetString()).ToString(),
                                _ => throw new InvalidOperationException($"Tipo inesperado para No_Fact_DIAN: {noFact.ValueKind}")
                            };

                            facturaElectronica = $"{prefijo.GetString()}{noFactSinCero}";
                        }
                        else if (json.TryGetProperty("Observaciones", out var obs))
                        {
                            facturaElectronica = "Procesando...";
                        }
                    }
                    catch
                    {
                        facturaElectronica = "Procesando...";
                    }
                }
                return new VentaFacturaModel
                {
                    idVenta = (int)dr["IdVentaCombustible"],
                    FacturaElectronica = facturaElectronica,
                    Sincronizado = sincronizado,
                };
            }
            catch (Exception ex)
            {
                return null;
            }
        }

        public void GuardarMarcacionesRapidas(MarcacionRapidaModel marcaciones)
        {
            if (marcaciones.Dinero == null || marcaciones.Volumen == null)
                throw new Exception("Marcaciones inválidas");

            if (marcaciones.Dinero.Count > 3 || marcaciones.Volumen.Count > 3)
                throw new Exception("Máximo 3 marcaciones permitidas");

            if (marcaciones.Dinero.Any(x => x <= 0))
                throw new Exception("Valores de dinero inválidos");

            if (marcaciones.Volumen.Any(x => x <= 0))
                throw new Exception("Valores de volumen inválidos");

            var dineroActual = ObtenerConfiguracionEstacion("DineroPredeterminado");
            var volumenActual = ObtenerConfiguracionEstacion("VolumenPredeterminado");

            var dineroArray = dineroActual.Split('|').ToList();
            var volumenArray = volumenActual.Split('|').ToList();

            while (dineroArray.Count < 3) dineroArray.Add("0");
            while (volumenArray.Count < 3) volumenArray.Add("0");

            for (int i = 0; i < 3; i++)
            {
                dineroArray[i] = marcaciones.Dinero.Count > i
                    ? marcaciones.Dinero[i].ToString(CultureInfo.InvariantCulture)
                    : "0";

                volumenArray[i] = marcaciones.Volumen.Count > i
                    ? marcaciones.Volumen[i].ToString(CultureInfo.InvariantCulture)
                    : "0";
            }

            // 🔹 Reconstruir string completo
            var nuevoDinero = string.Join("|", dineroArray);
            var nuevoVolumen = string.Join("|", volumenArray);

            // 🔹 Guardar en BD
            GuardarConfiguracionEstacion("DineroPredeterminado", nuevoDinero);
            GuardarConfiguracionEstacion("VolumenPredeterminado", nuevoVolumen);
        }

        public void GuardarConfiguracionEstacion(string nombre, string valor)
        {
            using var conn = _conexion.CrearConexion();
            using var cmd = new SqlCommand();

            try
            {
                cmd.Connection = conn;

                cmd.CommandText = @"UPDATE [dbo].[ConfiguracionEstacion]
                                    SET [Valor] = @Valor
                                    WHERE [Nombre] = @Nombre";

                cmd.Parameters.AddWithValue("@Valor", valor);
                cmd.Parameters.AddWithValue("@Nombre", nombre);

                conn.Open();

                var rows = cmd.ExecuteNonQuery();

                if (rows == 0)
                    throw new Exception($"No se encontró configuración: {nombre}");
            }
            catch (Exception)
            {
                throw; 
            }
        }

        public void GuardarConfiguracionesAutoservice(ConfiguracionAutoservicioRequest request)
        {
            if (request == null)
                return;

            // Validar Sistema
            if (request.Sistema != "NSX" && request.Sistema != "GNESYS")
                throw new Exception("Sistema debe ser 'NSX' o 'GNESYS'");

            // Validar MaxVueltos como número
            if (!double.TryParse(
                    request.MaxVueltos?.Replace(',', '.'),
                    NumberStyles.Float,
                    CultureInfo.InvariantCulture,
                    out double maxVueltos))
            {
                throw new Exception($"MaxVueltos no es un número válido: '{request.MaxVueltos}'");
            }

            var configuraciones = new List<(string Nombre, string Valor)>
            {
                ("Sistema",    request.Sistema),
                ("MaxVueltos", ((long)maxVueltos).ToString(CultureInfo.InvariantCulture)),
            };

            using var conn = _conexion.CrearConexion();
            conn.Open();
            using var tx = conn.BeginTransaction();

            try
            {
                using var cmd = new SqlCommand
                {
                    Connection = conn,
                    Transaction = tx,
                    CommandText = @"UPDATE [Autoservice].[Configuracion]
                            SET [Valor] = @Valor
                            WHERE [Nombre] = @Nombre"
                };

                var pNombre = cmd.Parameters.Add("@Nombre", SqlDbType.NVarChar, 100);
                var pValor = cmd.Parameters.Add("@Valor", SqlDbType.NVarChar, -1);

                var noEncontradas = new List<string>();

                foreach (var (nombre, valor) in configuraciones)
                {
                    pNombre.Value = nombre;
                    pValor.Value = (object)valor ?? DBNull.Value;

                    var rows = cmd.ExecuteNonQuery();
                    if (rows == 0)
                        noEncontradas.Add(nombre);
                }

                if (noEncontradas.Count > 0)
                    throw new Exception($"No se encontraron configuraciones: {string.Join(", ", noEncontradas)}");

                tx.Commit();
            }
            catch
            {
                tx.Rollback();
                throw;
            }
        }

        public void GuardarMangueras(List<MangueraItem> mangueras)
        {
            if (mangueras == null || !mangueras.Any())
                throw new Exception("No hay mangueras para guardar");

            try
            {
                foreach (var m in mangueras)
                {
                    // 🔹 Lado
                    UpsertRecurso(
                        "Lado",
                        "Lado Manguera",
                        "PosicionGrado",
                        m.IdPosicionGrado,
                        m.Lado
                    );

                    // 🔹 Color
                    UpsertRecurso(
                        "Color",
                        "Color Manguera",
                        "PosicionGrado",
                        m.IdPosicionGrado,
                        m.Color
                    );
                }
            }
            catch
            {
                throw;
            }
        }

        public void GuardarColores(List<string> colores)
        {
            if (colores == null || !colores.Any())
                throw new Exception("No hay colores para guardar");

            try
            {
                for (int i = 0; i < colores.Count; i++)
                {
                    UpsertRecurso(
                        $"Color{i + 1}",
                        "Color Interfaz",
                        "Bandera",
                        1,
                        colores[i]
                    );
                }
            }
            catch
            {
                throw;
            }
        }

        private void UpsertRecurso(string nombre, string tipo, string entidad, int idEntidad, string valor)
        {
            using var conn = _conexion.CrearConexion();
            using var cmd = new SqlCommand();

            try
            {
                cmd.Connection = conn;

                cmd.CommandText = @"
                                    IF EXISTS (
                                        SELECT 1 
                                        FROM [Autoservice].[Recursos]
                                        WHERE Nombre = @Nombre 
                                          AND Entidad = @Entidad 
                                          AND IdEntidad = @IdEntidad
                                          AND Activo = 1
                                    )
                                    BEGIN
                                        UPDATE [Autoservice].[Recursos]
                                        SET Valor = @Valor
                                        WHERE Nombre = @Nombre 
                                          AND Entidad = @Entidad 
                                          AND IdEntidad = @IdEntidad
                                          AND Activo = 1
                                    END
                                    ELSE
                                    BEGIN
                                        INSERT INTO [Autoservice].[Recursos]
                                        (Nombre, Tipo, Entidad, IdEntidad, Valor, Activo, FechaRegistro)
                                        VALUES
                                        (@Nombre, @Tipo, @Entidad, @IdEntidad, @Valor, 1, GETDATE())
                                    END
                                ";

                cmd.Parameters.AddWithValue("@Nombre", nombre);
                cmd.Parameters.AddWithValue("@Tipo", tipo);
                cmd.Parameters.AddWithValue("@Entidad", entidad);
                cmd.Parameters.AddWithValue("@IdEntidad", idEntidad);
                cmd.Parameters.AddWithValue("@Valor", valor);

                conn.Open();

                cmd.ExecuteNonQuery();
            }
            catch (Exception)
            {
                throw;
            }
        }

        public void GuardarMaximosPreset(List<ProductoPresetItem> productos)
        {
            if (productos == null || !productos.Any())
                throw new Exception("No hay productos");

            try
            {
                foreach (var p in productos)
                {
                    if (p.MaximoPreset <= 0)
                        throw new Exception($"Preset inválido para producto {p.IdProducto}");
                    if (p.MaximoPreset > 999900)
                        throw new Exception($"Preset demasiado alto para producto {p.IdProducto}");

                    UpsertRecurso(
                        "MaximoPreset",
                        "Preset Maximo en Dinero",
                        "Producto",
                        p.IdProducto,
                        p.MaximoPreset.ToString()
                    );
                }
            }
            catch
            {
                throw;
            }
        }

        public void GuardarPantallas(List<PantallaRequest> pantallas)
        {
            if (pantallas == null || !pantallas.Any())
                throw new Exception("No hay pantallas");

            foreach (var p in pantallas)
            {
                if (p.IdPosicion <= 0)
                    throw new Exception("Posición inválida");

                // ─── SERIAL ─────────────────────────────
                if (!string.IsNullOrEmpty(p.SerialPantalla))
                {
                    if (p.SerialPantalla.Length < 5)
                        throw new Exception($"Serial inválido para posición {p.IdPosicion}");

                    UpsertRecurso(
                        "SerialPantalla",
                        "Serial",
                        "Posicion",
                        p.IdPosicion,
                        p.SerialPantalla
                    );
                }

                if (!string.IsNullOrEmpty(p.CodigoTankio))
                {
                    UpsertRecurso(
                        "QRTankio",
                        "Codigo",
                        "Posicion",
                        p.IdPosicion,
                        p.CodigoTankio
                    );
                }
            }
        }

        public void GuardarDispositivos(
    List<DispositivoModel> dispositivos)
        {
            if (dispositivos == null || !dispositivos.Any())
                throw new Exception("No hay dispositivos");

            foreach (var d in dispositivos)
            {
                if (d.IdDispensador <= 0)
                    throw new Exception("Dispensador inválido");

                if (string.IsNullOrWhiteSpace(d.Identificador))
                    throw new Exception("Identificador inválido");

                if (d.Identificador.Length != 12)
                    throw new Exception(
                        $"MAC inválida: {d.Identificador}");

                if (string.IsNullOrWhiteSpace(d.Ip))
                    throw new Exception(
                        $"IP inválida para el dispositivo {d.Identificador}");

                if (d.IdentificadoresCliente != null
                    && !System.Text.RegularExpressions.Regex.IsMatch(d.IdentificadoresCliente, @"^[01]\|[01]\|[01]$"))
                    throw new Exception(
                        $"Identificadores inválidos para el dispositivo {d.Identificador}: use el formato iButton|Teclado|Placa, por ejemplo 1|0|1");

                if (d.IntervaloTiempoReal != null && (d.IntervaloTiempoReal < 200 || d.IntervaloTiempoReal > 5000))
                    throw new Exception(
                        $"Intervalo de tiempo real inválido para el dispositivo {d.Identificador}: use entre 200 y 5000 ms");

                GuardarDispositivo(
                    d.IdDispensador,
                    d.Identificador,
                    d.Ip);

                GuardarOpcionesDispositivo(d);
            }
        }

        // Las columnas de opciones solo existen en las bases con sus scripts aplicados; si no vienen o no existen, no se tocan
        private void GuardarOpcionesDispositivo(DispositivoModel d)
        {
            if (d.ModoHibrido == null && d.IdentificadoresCliente == null && d.TiempoReal == null && d.IntervaloTiempoReal == null)
                return;

            using var conn = _conexion.CrearConexion();
            using var cmd = new SqlCommand();
            cmd.Connection = conn;
            cmd.CommandText = @"
                IF @ModoHibrido IS NOT NULL AND COL_LENGTH('Autoservice.Dispositivo', 'ModoHibrido') IS NOT NULL
                    EXEC sp_executesql
                        N'UPDATE [Autoservice].[Dispositivo] SET ModoHibrido = @H WHERE IdDispensador = @D AND Activo = 1',
                        N'@H bit, @D int', @H = @ModoHibrido, @D = @IdDispensador;

                IF @Identificadores IS NOT NULL AND COL_LENGTH('Autoservice.Dispositivo', 'IdentificadoresCliente') IS NOT NULL
                    EXEC sp_executesql
                        N'UPDATE [Autoservice].[Dispositivo] SET IdentificadoresCliente = @I WHERE IdDispensador = @D AND Activo = 1',
                        N'@I varchar(20), @D int', @I = @Identificadores, @D = @IdDispensador;

                IF @TiempoReal IS NOT NULL AND COL_LENGTH('Autoservice.Dispositivo', 'TiempoReal') IS NOT NULL
                    EXEC sp_executesql
                        N'UPDATE [Autoservice].[Dispositivo] SET TiempoReal = @T WHERE IdDispensador = @D AND Activo = 1',
                        N'@T bit, @D int', @T = @TiempoReal, @D = @IdDispensador;

                IF @Intervalo IS NOT NULL AND COL_LENGTH('Autoservice.Dispositivo', 'IntervaloTiempoReal') IS NOT NULL
                    EXEC sp_executesql
                        N'UPDATE [Autoservice].[Dispositivo] SET IntervaloTiempoReal = @M WHERE IdDispensador = @D AND Activo = 1',
                        N'@M int, @D int', @M = @Intervalo, @D = @IdDispensador;";
            cmd.Parameters.AddWithValue("@IdDispensador", d.IdDispensador);
            cmd.Parameters.AddWithValue("@ModoHibrido", (object?)d.ModoHibrido ?? DBNull.Value);
            cmd.Parameters.AddWithValue("@Identificadores", (object?)d.IdentificadoresCliente ?? DBNull.Value);
            cmd.Parameters.AddWithValue("@TiempoReal", (object?)d.TiempoReal ?? DBNull.Value);
            cmd.Parameters.AddWithValue("@Intervalo", (object?)d.IntervaloTiempoReal ?? DBNull.Value);

            conn.Open();
            cmd.ExecuteNonQuery();
        }

        // Programas de fidelidad de la administración (ids fijos)
        private static readonly (int Id, string Nombre)[] ProgramasFidelidad =
        {
            (1, "PuntosColombia"),
            (2, "ViveTerpel"),
            (3, "Commodo"),
            (4, "Local"),
            (5, "Leal")
        };

        // Los cinco programas con su estado en Autoservice.Fidelidad; el que no tiene fila queda inactivo
        public List<FidelidadConfigModel> ObtenerFidelidadConfiguracion()
        {
            var activos = new Dictionary<int, bool>();

            using var conn = _conexion.CrearConexion();
            using var cmd = new SqlCommand("SELECT IdFidelidadAuto, Activo FROM [Autoservice].[Fidelidad]", conn);
            conn.Open();
            using var dr = cmd.ExecuteReader();
            while (dr.Read())
                activos[(int)dr["IdFidelidadAuto"]] = (bool)dr["Activo"];

            return ProgramasFidelidad
                .Select(p => new FidelidadConfigModel
                {
                    IdFidelidad = p.Id,
                    Nombre = p.Nombre,
                    Activo = activos.TryGetValue(p.Id, out var activo) && activo
                })
                .ToList();
        }

        public void GuardarFidelidadConfiguracion(List<FidelidadConfigModel> programas)
        {
            if (programas == null || !programas.Any())
                throw new Exception("No hay programas de fidelidad");

            foreach (var p in programas)
            {
                if (!ProgramasFidelidad.Any(x => x.Id == p.IdFidelidad))
                    throw new Exception($"Programa de fidelidad inválido: {p.IdFidelidad}");
            }

            using var conn = _conexion.CrearConexion();
            conn.Open();
            using var tx = conn.BeginTransaction();
            foreach (var p in programas)
            {
                using var cmd = new SqlCommand(@"
                    IF EXISTS (SELECT 1 FROM [Autoservice].[Fidelidad] WHERE IdFidelidadAuto = @Id)
                        UPDATE [Autoservice].[Fidelidad] SET Activo = @Activo WHERE IdFidelidadAuto = @Id
                    ELSE
                        INSERT [Autoservice].[Fidelidad] (IdFidelidadAuto, Descripcion, Activo, FechaRegistro)
                        VALUES (@Id, @Nombre, @Activo, GETDATE())", conn, tx);
                cmd.Parameters.AddWithValue("@Id", p.IdFidelidad);
                cmd.Parameters.AddWithValue("@Nombre", ProgramasFidelidad.First(x => x.Id == p.IdFidelidad).Nombre);
                cmd.Parameters.AddWithValue("@Activo", p.Activo);
                cmd.ExecuteNonQuery();
            }
            tx.Commit();
        }

        private void GuardarDispositivo(int idDispensador, string identificador,string ip)
        {
            using var conn = _conexion.CrearConexion();
            using var cmd = new SqlCommand();

            try
            {
                cmd.Connection = conn;

                cmd.CommandText = @"
                                    IF EXISTS (
                                        SELECT 1
                                        FROM [Autoservice].[Dispositivo]
                                        WHERE Identificador = @Identificador
                                          AND IdDispensador <> @IdDispensador
                                          AND Activo = 1
                                    )
                                    BEGIN
                                        THROW 50001, 'El identificador ya está en uso', 1;
                                    END

                                    IF EXISTS (
                                        SELECT 1
                                        FROM [Autoservice].[Dispositivo]
                                        WHERE IdDispensador = @IdDispensador
                                          AND Activo = 1
                                    )
                                    BEGIN
                                        UPDATE [Autoservice].[Dispositivo]
                                        SET
                                            Identificador = @Identificador,
                                            Ip = @Ip
                                        WHERE IdDispensador = @IdDispensador
                                          AND Activo = 1
                                    END
                                    ELSE
                                    BEGIN
                                        INSERT INTO [Autoservice].[Dispositivo]
                                        (
                                            Identificador,
                                            IdDispensador,
                                            Ip,
                                            Activo,
                                            FechaRegistro
                                        )
                                        VALUES
                                        (
                                            @Identificador,
                                            @IdDispensador,
                                            @Ip,
                                            1,
                                            GETDATE()
                                        )
                                    END
                                ";
                cmd.Parameters.AddWithValue("@Identificador", identificador);
                cmd.Parameters.AddWithValue("@IdDispensador", idDispensador);
                cmd.Parameters.AddWithValue("@Ip", ip);

                conn.Open();

                cmd.ExecuteNonQuery();
            }
            catch (Exception)
            {
                throw;
            }
        }

        public UsuarioModel ValidarLogin(string userName, string password)
        {
            using var conn = _conexion.CrearConexion();
            using var cmd = new SqlCommand();

            try
            {
                cmd.Connection = conn;

                cmd.CommandText = @"
                                    SELECT TOP 1
                                        Pk_IdUsuario,
                                        Nombres,
                                        Apellidos,
                                        UserName,
                                        Contraseña,
                                        Email,
                                        Fk_IdRol,
                                        Activo
                                    FROM [Usuario].[Usuarios]
                                    WHERE UserName = @UserName
                                      AND Activo = 1";

                cmd.Parameters.AddWithValue("@UserName", userName);

                conn.Open();

                using var dr = cmd.ExecuteReader();

                if (!dr.Read())
                    return null;

                var passwordBD = (string)dr["Contraseña"];
                EncriptionHelper enc = new EncriptionHelper();
                if (passwordBD != enc.Encrypt(password))
                    return null;

                return new UsuarioModel
                {
                    IdUsuario = (int)dr["Pk_IdUsuario"],
                    Nombres = dr["Nombres"].ToString(),
                    UserName = dr["UserName"].ToString(),
                };
            }
            catch
            {
                return null;
            }
        }

        public object ObtenerDispositivos()
        {
            List<DispositivoModel> dispositivos = new List<DispositivoModel>();

            using var conn = _conexion.CrearConexion();

            using var co = new SqlCommand();
            co.Connection = conn;

            try
            {
                conn.Open();

                // Las columnas de opciones solo existen en las bases con sus scripts aplicados
                co.CommandText = @"SELECT COL_LENGTH('Autoservice.Dispositivo', 'ModoHibrido'),
                                          COL_LENGTH('Autoservice.Dispositivo', 'IdentificadoresCliente'),
                                          COL_LENGTH('Autoservice.Dispositivo', 'IntervaloTiempoReal')";
                string campoHibrido = "CAST(0 AS bit)";
                string campoIdentificadores = "CAST('1|1|1' AS varchar(20))";
                string camposTiempoReal = "CAST(0 AS bit) AS TiempoReal, CAST(500 AS int) AS IntervaloTiempoReal";
                using (SqlDataReader drColumnas = co.ExecuteReader())
                {
                    if (drColumnas.Read())
                    {
                        if (drColumnas[0] != DBNull.Value) campoHibrido = "[ModoHibrido]";
                        if (drColumnas[1] != DBNull.Value) campoIdentificadores = "[IdentificadoresCliente]";
                        if (drColumnas[2] != DBNull.Value) camposTiempoReal = "[TiempoReal], [IntervaloTiempoReal]";
                    }
                }

                co.CommandText = @$"SELECT [IdDispositivo],[Identificador],[IdDispensador],[Ip],[Activo],
                                           {campoHibrido} AS ModoHibrido, {campoIdentificadores} AS IdentificadoresCliente, {camposTiempoReal}
                                    FROM [Autoservice].[Dispositivo]
                                    WHERE Activo = 1";

                using SqlDataReader dr = co.ExecuteReader();

                while (dr.Read())
                {
                    DispositivoModel dispositivo = new DispositivoModel();
                    dispositivo.IdDispositivo = (int)dr["IdDispositivo"];
                    dispositivo.IdDispensador = (int)dr["IdDispensador"];
                    dispositivo.Identificador = (string)dr["Identificador"];
                    dispositivo.Ip = (string)dr["Ip"];
                    dispositivo.Activo = (bool)dr["Activo"];
                    dispositivo.ModoHibrido = dr["ModoHibrido"] != DBNull.Value && (bool)dr["ModoHibrido"];
                    dispositivo.IdentificadoresCliente = dr["IdentificadoresCliente"] as string ?? "1|1|1";
                    dispositivo.TiempoReal = dr["TiempoReal"] as bool? ?? false;
                    dispositivo.IntervaloTiempoReal = dr["IntervaloTiempoReal"] as int? ?? 500;
                    dispositivos.Add(dispositivo);
                }
            }
            catch (Exception)
            {
                throw;
            }
            finally
            {
                conn.Close();
            }
            return dispositivos;
        }
        public List<DispensadorEDSModel> ObtenerDispensadoresEDS()
        {
            List<DispensadorEDSModel> dispensadores = new List<DispensadorEDSModel>();
            int IdDispensador = 0;

            using var conn = _conexion.CrearConexion();

            using var co = new SqlCommand();
            co.Connection = conn;

            try
            {
                co.CommandText = @$"SELECT [Pk_IdDispensador],[Marca],[Modelo]
                                    FROM [dbo].[Dispensador]
                                    WHERE Activo = 1";


                conn.Open();
                using SqlDataReader dr = co.ExecuteReader();

                while (dr.Read())
                {
                    DispensadorEDSModel dispensadorEDS = new DispensadorEDSModel();
                    dispensadorEDS.IdDispensador = (int)dr["Pk_IdDispensador"];
                    dispensadorEDS.Marca = (string)dr["Marca"];
                    dispensadorEDS.Modelo = (string)dr["Modelo"];
                    dispensadorEDS.Caras = ObtenerCarasByIdDispensador(dispensadorEDS.IdDispensador);
                    dispensadores.Add(dispensadorEDS);
                    
                }
            }
            catch (Exception)
            {
                throw;
            }
            finally
            {
                conn.Close();
            }
            return dispensadores;
        }
        public CatalogosModel ObtenerCatalogos()
        {
            var result = new CatalogosModel();

            result.FormasPagoSistema = ObtenerFormasPago();
            result.FormasPagoAuto = ObtenerFormasDePagoAdmin();
            result.Productos = ObtenerPrecios();
            result.Colores = ObtenerColoresBandera();
            result.Turnos = ObtenerTurnos();

            return result;
        }

        public List<FormaPagoSistemaModel> ObtenerFormasPago()
        {
            var lista = new List<FormaPagoSistemaModel>();

            using var conn = _conexion.CrearConexion();
            using var cmd = new SqlCommand();

            cmd.Connection = conn;
            cmd.CommandText = @"SELECT Pk_IdFormaPago, NombreFormaPago
                        FROM [FormaPago].[FormaPago]
                        WHERE Activo = 1";

            conn.Open();

            using var dr = cmd.ExecuteReader();

            while (dr.Read())
            {
                lista.Add(new FormaPagoSistemaModel
                {
                    IdFormaPago = (int)dr["Pk_IdFormaPago"],
                    Descripcion = (string)dr["NombreFormaPago"]
                });
            }

            return lista;
        }

        public void GuardarFormasPago(List<FormaPagoAutoRequest> formasPago)
        {
            if (formasPago == null || !formasPago.Any())
                throw new Exception("No hay formas de pago para configurar");

            foreach (var fp in formasPago)
            {
                if (fp.IdFormaPagoAuto != 1 && fp.IdFormaPagoAuto != 2 && fp.IdFormaPagoAuto != 3)
                    throw new Exception($"IdFormaPagoAuto inválido: {fp.IdFormaPagoAuto}");

                if (fp.IdFormaPago <= 0)
                    throw new Exception($"Forma de pago del sistema inválida para {fp.IdFormaPagoAuto}");

                if (string.IsNullOrWhiteSpace(fp.Descripcion))
                    throw new Exception($"Descripción inválida para {fp.IdFormaPagoAuto}");

                UpsertFormaPagoAuto(fp);
            }
        }
        public void UpsertFormaPagoAuto(FormaPagoAutoRequest fp)
        {
            using var conn = _conexion.CrearConexion();
            using var cmd = new SqlCommand();

            cmd.Connection = conn;

            cmd.CommandText = @"
                                IF EXISTS (
                                    SELECT 1 
                                    FROM [Autoservice].[FormaPago]
                                    WHERE IdFormaPagoAuto = @IdFormaPagoAuto
                                )
                                BEGIN
                                    UPDATE [Autoservice].[FormaPago]
                                    SET
                                        Fk_IdFormaPago = @Fk_IdFormaPago,
                                        Descripcion = @Descripcion,
                                        Activo = @Activo
                                    WHERE IdFormaPagoAuto = @IdFormaPagoAuto
                                END
                                ELSE
                                BEGIN
                                    INSERT INTO [Autoservice].[FormaPago]
                                    (IdFormaPagoAuto, Fk_IdFormaPago, Activo, Descripcion, FechaRegistro)
                                    VALUES
                                    (@IdFormaPagoAuto, @Fk_IdFormaPago, @Activo, @Descripcion, GETDATE())
                                END
                            ";

            cmd.Parameters.AddWithValue("@IdFormaPagoAuto", fp.IdFormaPagoAuto);
            cmd.Parameters.AddWithValue("@Fk_IdFormaPago", fp.IdFormaPago);
            cmd.Parameters.AddWithValue("@Descripcion", fp.Descripcion);
            cmd.Parameters.AddWithValue("@Activo", fp.Activo);

            conn.Open();
            cmd.ExecuteNonQuery();
        }

        public AutoservicioVueltosModel ObtenerEstadoVueltos(string codigo)
        {
            using var conn = _conexion.CrearConexion();
            using var cmd = new SqlCommand();
            try
            {
                cmd.Connection = conn;

                cmd.CommandText = @"
                                    SELECT 
                                        IdVueltos,
                                        Codigo,
                                        Valor,
                                        IdEstadoVuelto,
                                        IdDisPosProgramacion,
                                        FechaCreacion,
                                        FechaUso,
                                        IdTurno,
                                        IdDetalleFormaPago
                                    FROM [Autoservice].[Vueltos]
                                    WHERE Codigo = @Codigo";

                cmd.Parameters.AddWithValue("@Codigo", codigo);

                conn.Open();

                using var dr = cmd.ExecuteReader();

                if (!dr.Read())
                    return null;

                return new AutoservicioVueltosModel
                {
                    IdVueltos = (int)dr["IdVueltos"],
                    Codigo = (string)dr["Codigo"],
                    Valor = dr["Valor"] != DBNull.Value ? Convert.ToDouble(dr["Valor"]) : 0,
                    IdEstadoVuelto = (int)dr["IdEstadoVuelto"],
                    IdDisPosProgramacion = dr["IdDisPosProgramacion"] != DBNull.Value ? (int?)dr["IdDisPosProgramacion"] : null,
                    FechaCreacion = (DateTime)dr["FechaCreacion"],
                    FechaUso = dr["FechaUso"] != DBNull.Value ? (DateTime?)dr["FechaUso"] : null,
                    IdTurno = dr["IdTurno"] != DBNull.Value ? (int?)dr["IdTurno"] : null,
                    IdDetalleFormaPago = dr["IdDetalleFormaPago"] != DBNull.Value ? (int?)dr["IdDetalleFormaPago"] : null
                };
            }
            catch (Exception ex)
            {
                return null;
            }
        }

        public AutoservicioVueltosModel ObtenerVueltoByIdPreset(int idPreset)
        {
            using var conn = _conexion.CrearConexion();
            using var cmd = new SqlCommand();
            try
            {
                cmd.Connection = conn;

                cmd.CommandText = @"
                                    SELECT 
                                        IdVueltos,
                                        Codigo,
                                        Valor,
                                        IdDisPosProgramacion,
                                        IdEstadoVuelto,
                                        FechaCreacion,
                                        FechaUso,
                                        IdTurno,
                                        IdDetalleFormaPago
                                    FROM [Autoservice].[Vueltos]
                                    WHERE IdDisPosProgramacion = @IdDisPosProgramacion";

                cmd.Parameters.AddWithValue("@IdDisPosProgramacion", idPreset);

                conn.Open();

                using var dr = cmd.ExecuteReader();

                if (!dr.Read())
                    return null;

                return new AutoservicioVueltosModel
                {
                    IdVueltos = (int)dr["IdVueltos"],
                    Codigo = (string)dr["Codigo"],
                    Valor = dr["Valor"] != DBNull.Value ? Convert.ToDouble(dr["Valor"]) : 0,
                    IdEstadoVuelto = (int)dr["IdEstadoVuelto"],
                    FechaCreacion = (DateTime)dr["FechaCreacion"],
                    FechaUso = dr["FechaUso"] != DBNull.Value ? (DateTime?)dr["FechaUso"] : null,
                    IdTurno = dr["IdTurno"] != DBNull.Value ? (int?)dr["IdTurno"] : null,
                    IdDetalleFormaPago = dr["IdDetalleFormaPago"] != DBNull.Value ? (int?)dr["IdDetalleFormaPago"] : null
                };
            }
            catch (Exception ex)
            {
                return null;
            }
        }

        public bool ReservarVuelto(string codigo, double valor)
        {
            using var conn = _conexion.CrearConexion();
            using var cmd = new SqlCommand();

            try
            {
                cmd.Connection = conn;

                cmd.CommandText = @"
                                    UPDATE Autoservice.Vueltos
                                    SET IdEstadoVuelto = 2
                                    WHERE Codigo = @Codigo
                                    AND IdEstadoVuelto = 1
                                    AND Valor = @Valor";
                
                cmd.Parameters.AddWithValue("@Codigo", codigo);
                cmd.Parameters.AddWithValue("@Valor", valor);

                conn.Open();

                int filas = cmd.ExecuteNonQuery();

                return filas > 0;
            }
            catch (Exception ex)
            {
                // opcional log
                return false;
            }
        }

        public bool InsertarVueltosAutoservice(AutoservicioVueltosModel autoservicioVueltosModel)
        {
            using var conn = _conexion.CrearConexion();
            conn.Open();
            using var transaction = conn.BeginTransaction();
            try
            {
                using var cmd = new SqlCommand();
                cmd.Connection = conn;
                cmd.Transaction = transaction;

                cmd.CommandText = @"INSERT INTO [Autoservice].[Vueltos]
                                    ([Codigo],[Valor],[IdDisPosProgramacion],[IdEstadoVuelto],[IdFormaPago])
                                     VALUES
                                    (
                                   @Codigo,
                                   @Valor,
                                   @IdDisPosProg,
                                   @IdEstadoVuelto,
                                   @IdFormaPago)";

                cmd.Parameters.AddWithValue("@Codigo", autoservicioVueltosModel.Codigo);
                cmd.Parameters.AddWithValue("@Valor", autoservicioVueltosModel.Valor);
                cmd.Parameters.AddWithValue("@IdDisPosProg", autoservicioVueltosModel.IdDisPosProgramacion);
                cmd.Parameters.AddWithValue("@IdEstadoVuelto", autoservicioVueltosModel.IdEstadoVuelto);
                cmd.Parameters.AddWithValue("@IdFormaPago", autoservicioVueltosModel.IdFormaPago);

                cmd.ExecuteNonQuery();

                transaction.Commit();
                return true;
            }
            catch (Exception ex)
            {
                LogInfo($"Error al insertar vuelto  {ex.Message}");
                transaction.Rollback();
                throw;
                return false;
            }
        }

        public string GenerarCodigo()
        {
            return new string(Enumerable.Range(0, 6)
                .Select(_ => _chars[_random.Next(_chars.Length)]).ToArray());
        }

        public bool RedimirQRAuto(AutoservicioVueltosModel autoservicioVueltos)
        {
            using var conn = _conexion.CrearConexion();
            using var cmd = new SqlCommand();
            try
            {
                cmd.Connection = conn;
                cmd.CommandText = @"
                                    UPDATE Autoservice.Vueltos
                                    SET FechaUso            = GETDATE(),
                                        IdEstadoVuelto      = @IdEstadoUsado,
                                        IdDetalleFormaPago  = @IdDetalleFormaPago,
                                        IdFormaPago         = @IdFormaPago
                                    WHERE Codigo          = @Codigo
                                      AND IdEstadoVuelto <> @IdEstadoUsado";

                cmd.Parameters.AddWithValue("@Codigo", autoservicioVueltos.Codigo);
                cmd.Parameters.AddWithValue("@IdDetalleFormaPago", autoservicioVueltos.IdDetalleFormaPago);
                cmd.Parameters.AddWithValue("@IdFormaPago", autoservicioVueltos.IdFormaPago ?? (object)DBNull.Value);
                cmd.Parameters.AddWithValue("@IdEstadoUsado", (int)EstadoVueltoEnum.Usado);

                conn.Open();
                int filas = cmd.ExecuteNonQuery();
                return filas > 0;
            }
            catch (Exception ex)
            {
                return false;
            }
        }

        public string? GenerarVuelto(int idPreset, double valor, int idFormaPago)
        {
            string codigo = GenerarCodigo();
            LogInfo($"Vuelto {codigo}");
            AutoservicioVueltosModel autoservicioVueltos = new AutoservicioVueltosModel();
            autoservicioVueltos.Codigo = codigo;
            autoservicioVueltos.IdDisPosProgramacion = idPreset;
            autoservicioVueltos.Valor = valor;
            autoservicioVueltos.IdEstadoVuelto = (int)EstadoVueltoEnum.Creado;
            autoservicioVueltos.IdFormaPago = idFormaPago;
            DispPosProgramacionModel dispPosProgramacion = new DispPosProgramacionModel();
            dispPosProgramacion = ObtenerDispPosProgramacion(idPreset);
            if (InsertarVueltosAutoservice(autoservicioVueltos))
            {
                ImprimirQrVueltos(autoservicioVueltos, dispPosProgramacion);
                return codigo;
            }
            else return null;
        }

        public void ImprimirQrVueltos(AutoservicioVueltosModel autoservicioVueltos, DispPosProgramacionModel programacion)
        {
            string imprimir = string.Empty;
            imprimir = "NSX2:|";
            imprimir += "-----------------------------------------|";
            imprimir += "           CODIGO QR VUELTOS               |";
            imprimir += "-----------------------------------------|";
            imprimir += "       !Tienes un saldo a tu favor!        |";
            imprimir += $"Codigo      : {autoservicioVueltos.Codigo}|";
            imprimir += $"Fecha       : {DateTime.Now.ToString("yyyyMMdd HH:mm:ss")}|";
            imprimir += $"Valor Pago  : ${programacion.ValorProgramado.ToString("N0")}|";
            imprimir += $"Valor Venta : ${programacion.ValorDispensado.Value.ToString("N0")}|";
            imprimir += $"Valor Codigo: ${autoservicioVueltos.Valor.ToString("N0")}|";
            imprimir += "CodigoQR|" + autoservicioVueltos.Codigo;

            InsertarMensajeImprimir(0, programacion.IdPosicion, imprimir, false);
        }

        public DispPosProgramacionModel ObtenerDispPosProgramacion(int? idDispPosProgramacion)
        {
            if(idDispPosProgramacion == null)
            {
                return null;
            }
            using var conn = _conexion.CrearConexion();
            using var cmd = new SqlCommand();
            try
            {
                cmd.Connection = conn;
                cmd.CommandText = @"
                                    SELECT 
                                        [Pk_IdDispensadorPosicionEstado],
                                        [Guid],
                                        [FechaInicial],
                                        [DineroInicial],
                                        [VolumenInicial],
                                        [ValorProgramado],
                                        [ValorDispensado],
                                        [GradoVerificacion],
                                        [Placa],
                                        [Kilometraje],
                                        [IdentificadorWeb],
                                        [Fk_IdPosicion],
                                        [Fk_IdIsla],
                                        [Fk_IdProducto],
                                        [Fk_IdTipoTransaccion],
                                        [Fk_IdPosicionGrado],
                                        [Fk_IdIdentificador],
                                        [Fk_IdCuenta],
                                        [Fk_IdTipoProgramacion],
                                        [Fk_IdNivel],
                                        [Fk_IdVenta],
                                        [Fk_IdTurno],
                                        [Fk_IdPrecioProducto],
                                        [Fk_IdEstadoProgramacion],
                                        [Fk_IdCorte],
                                        [Fk_IdTipoSistema],
                                        [PrecioMaster]
                                    FROM [EstacionNSX].[dbo].[DispensadorPosicionProgramacion]
                                    WHERE [Pk_IdDispensadorPosicionEstado] = @IdDispPosProgramacion";
                cmd.Parameters.AddWithValue("@IdDispPosProgramacion", idDispPosProgramacion);
                conn.Open();
                using var dr = cmd.ExecuteReader();
                if (!dr.Read())
                    return null;
                return new DispPosProgramacionModel
                {
                    IdDispPosProgramacion = (int)dr["Pk_IdDispensadorPosicionEstado"],
                    Guid = (Guid)dr["Guid"],
                    FechaInicial = (DateTime)dr["FechaInicial"],
                    DineroInicial = dr["DineroInicial"] != DBNull.Value ? (double?)Convert.ToDouble(dr["DineroInicial"]) : null,
                    VolumenInicial = dr["VolumenInicial"] != DBNull.Value ? (double?)Convert.ToDouble(dr["VolumenInicial"]) : null,
                    ValorProgramado = Convert.ToDouble(dr["ValorProgramado"]),
                    ValorDispensado = dr["ValorDispensado"] != DBNull.Value ? (double?)Convert.ToDouble(dr["ValorDispensado"]) : null,
                    GradoVerificado = dr["GradoVerificacion"] != DBNull.Value ? (int?)Convert.ToInt32(dr["GradoVerificacion"]) : null,
                    Placa = dr["Placa"] != DBNull.Value ? (string)dr["Placa"] : null,
                    Kilometraje = dr["Kilometraje"] != DBNull.Value ? (double?)Convert.ToDouble(dr["Kilometraje"]) : null,
                    IdentificadorWeb = dr["IdentificadorWeb"] != DBNull.Value ? (string)dr["IdentificadorWeb"] : null,
                    IdPosicion = (int)dr["Fk_IdPosicion"],
                    IdIsla = dr["Fk_IdIsla"] != DBNull.Value ? (int?)Convert.ToInt32(dr["Fk_IdIsla"]) : null,
                    IdProducto = dr["Fk_IdProducto"] != DBNull.Value ? (int?)Convert.ToInt32(dr["Fk_IdProducto"]) : null,
                    IdTipoTransaccion = dr["Fk_IdTipoTransaccion"] != DBNull.Value ? (int?)Convert.ToInt32(dr["Fk_IdTipoTransaccion"]) : null,
                    IdPosicionGrado = dr["Fk_IdPosicionGrado"] != DBNull.Value ? (int?)Convert.ToInt32(dr["Fk_IdPosicionGrado"]) : null,
                    IdIdentificador = dr["Fk_IdIdentificador"] != DBNull.Value ? (int?)Convert.ToInt32(dr["Fk_IdIdentificador"]) : null,
                    IdCuenta = dr["Fk_IdCuenta"] != DBNull.Value ? (int?)Convert.ToInt32(dr["Fk_IdCuenta"]) : null,
                    IdTipoProgramacion = (int)dr["Fk_IdTipoProgramacion"],
                    IdNivel = dr["Fk_IdNivel"] != DBNull.Value ? (int?)Convert.ToInt32(dr["Fk_IdNivel"]) : null,
                    IdVenta = dr["Fk_IdVenta"] != DBNull.Value ? (int?)Convert.ToInt32(dr["Fk_IdVenta"]) : null,
                    IdTurno = dr["Fk_IdTurno"] != DBNull.Value ? (int?)Convert.ToInt32(dr["Fk_IdTurno"]) : null,
                    IdPrecioProducto = dr["Fk_IdPrecioProducto"] != DBNull.Value ? (int?)Convert.ToInt32(dr["Fk_IdPrecioProducto"]) : null,
                    IdEstadoProgramacion = (int)dr["Fk_IdEstadoProgramacion"],
                    IdCorte = dr["Fk_IdCorte"] != DBNull.Value ? (int?)Convert.ToInt32(dr["Fk_IdCorte"]) : null,
                    IdTipoSistema = dr["Fk_IdTipoSistema"] != DBNull.Value ? (int?)Convert.ToInt32(dr["Fk_IdTipoSistema"]) : null,
                    PrecioMaster = Convert.ToDouble(dr["PrecioMaster"]),
                };
            }
            catch (Exception ex)
            {
                return null;
            }
        }

        public void InsertarMensajeImprimir(int numeroFactura, int posicion, string mensaje, bool impreso)
        {
            using var conn = _conexion.CrearConexion();
            using var cmd = new SqlCommand();
            try
            {
                cmd.Connection = conn;
                cmd.CommandText = @"
                                    INSERT INTO [dbo].[ImpresionPosicion]
                                        ([ConsecutivoVenta], [Posicion], [DatosImpresion], [Impreso])
                                    VALUES
                (@NumeroFactura, @Posicion, @Mensaje, @Impreso)";
                cmd.Parameters.AddWithValue("@NumeroFactura", numeroFactura);
                cmd.Parameters.AddWithValue("@Posicion", posicion);
                cmd.Parameters.AddWithValue("@Mensaje", mensaje);
                cmd.Parameters.AddWithValue("@Impreso", impreso ? 1 : 0);
                conn.Open();
                cmd.ExecuteNonQuery();
            }
            catch (Exception ex)
            {
                // log si tienes el mecanismo disponible
            }
        }

        public void LogInfo(string message, string error = null)
        {
            using var conn = _conexion.CrearConexion();
            using var cmd = new SqlCommand();
            try
            {
                cmd.Connection = conn;
                cmd.CommandText = @"INSERT INTO [dbo].[Log] ([Date],[Thread],[Level],[Logger],[Message],[Exception])
                            VALUES
                            (@Fecha, @Thread, @Level,@Level, @Mensaje, @Exception)";
                cmd.Parameters.AddWithValue("@Fecha", DateTime.Now);
                cmd.Parameters.AddWithValue("@Thread", "ApiAutoservicio");
                cmd.Parameters.AddWithValue("@Level", "INFO");
                cmd.Parameters.AddWithValue("@Mensaje", message);
                cmd.Parameters.AddWithValue("@Exception", "");
                conn.Open();
                cmd.ExecuteNonQuery();
            }
            catch (Exception ex)
            {
                // log si tienes el mecanismo disponible
            }
        }

        public bool RegistrarVuelto(RegistrarVueltoRequest request)
        {
            using var conn = _conexion.CrearConexion();
            using var cmd = new SqlCommand();
            try
            {
                cmd.Connection = conn;
                cmd.CommandText = @"
                                    INSERT INTO [Autoservice].[Vueltos]
                                        ([Codigo], [Valor], [IdDisPosProgramacion], [IdEstadoVuelto], [FechaCreacion], [FechaUso], [IdFormaPago])
                                    VALUES
                                    (@Codigo, @Valor, @IdDisPosProgramacion, @IdEstadoVuelto, @FechaCreacion, @FechaUso, @IdFormaPago)";
                cmd.Parameters.AddWithValue("@Codigo", request.Codigo);
                cmd.Parameters.AddWithValue("@Valor", request.Valor);
                cmd.Parameters.AddWithValue("@IdDisPosProgramacion", (object?)request.IdDisPosProgramacion ?? DBNull.Value);
                cmd.Parameters.AddWithValue("@IdEstadoVuelto", (int)EstadoVueltoEnum.Usado);
                cmd.Parameters.AddWithValue("@FechaCreacion", request.FechaCreacion);
                cmd.Parameters.AddWithValue("@FechaUso", (object?)request.FechaUso ?? DBNull.Value);
                cmd.Parameters.AddWithValue("@IdFormaPago", request.IdFormaPago);
                conn.Open();
                cmd.ExecuteNonQuery();
                return true;
            }
            catch (Exception ex)
            {
                return false;
            }
        }

        public VendedorModel ValidarVendedor(string documento,string password)
        {
            using var conn = _conexion.CrearConexion();
            using var cmd = new SqlCommand();
            EncriptionHelper enc = new EncriptionHelper();
            

            try
            {
                var passwordenc = enc.Encrypt(password);
                cmd.Connection = conn;

                cmd.CommandText = @"SELECT TOP 1
                                        Pk_IdIslero,
                                        Cedula,
                                        Nombres,
                                        Apellidos,
                                        Activo
                                    FROM [EstacionNSX].[Turnos].[Islero]
                                    WHERE Cedula = @Cedula AND Contraseña = @Password" ;

                cmd.Parameters.AddWithValue("@Cedula", documento);
                cmd.Parameters.AddWithValue("@Password", passwordenc);

                conn.Open();

                using var dr = cmd.ExecuteReader();

                if (!dr.Read())
                    return null;

                return new VendedorModel
                {
                    IdIslero = (int)dr["Pk_IdIslero"],
                    Cedula = (string)dr["Cedula"],
                    Nombre = (string)dr["Nombres"],
                    Apellidos = (string)dr["Apellidos"],
                    Activo = (bool)dr["Activo"]
                };
            }
            catch (Exception ex)
            {
                return null;
            }
        }

        public bool GuardarTurnos(List<TurnoItemModel> turnos)
        {
            if (turnos == null || !turnos.Any())
                return false;

            try
            {
                string valor = string.Join("|",
                    turnos.Select(t => $"{t.HoraInicio};{t.HoraFin}")
                );

                UpsertRecurso(
                    "Turnos",
                    "Configuracion Turnos",
                    "Bandera",
                    1,
                    valor
                );

                return true;
            }
            catch
            {
                return false;
            }
        }

        public List<TurnoItemModel> ObtenerTurnos()
        {
            try
            {
                var recurso = ObtenerRecurso(
                    "Turnos",
                    "Bandera",
                    1
                );

                if (recurso == null || string.IsNullOrWhiteSpace(recurso))
                    return new List<TurnoItemModel>();

                return recurso
                    .Split('|', StringSplitOptions.RemoveEmptyEntries)
                    .Select(t =>
                    {
                        var partes = t.Split(';');

                        return new TurnoItemModel
                        {
                            HoraInicio = partes[0],
                            HoraFin = partes[1]
                        };
                    })
                    .ToList();
            }
            catch
            {
                return new List<TurnoItemModel>();
            }
        }

        public DashboardResponseModel ObtenerDashboard(DateTime fechaInicio, DateTime fechaFin, int? idDispensador, int? idProducto)
        {
            if (fechaInicio == DateTime.MinValue)
                throw new Exception("Fecha inicio inválida");

            if (fechaFin == DateTime.MinValue)
                throw new Exception("Fecha fin inválida");

            if (fechaFin < fechaInicio)
                throw new Exception("La fecha fin no puede ser menor a la fecha inicio");

            DashboardResponseModel dashboard = new DashboardResponseModel();
            int idTipoAutoservicio = ObtenerIdTipoTransaccionAutoservicio();

            dashboard.Kpis = ObtenerKPIs(
                fechaInicio,
                fechaFin,
                idDispensador,
                idProducto,
                null
            );

            dashboard.Participacion = ObtenerParticipacion(
                fechaInicio,
                fechaFin,
                idTipoAutoservicio
            );

            dashboard.VentasPorDia = ObtenerVentasPorDia(
                fechaInicio,
                fechaFin,
                idTipoAutoservicio
            );

            dashboard.VentasPorProducto = ObtenerVentasPorProducto(
                fechaInicio,
                fechaFin,
                idTipoAutoservicio
            );

            dashboard.VentasPorFormaPago = ObtenerVentasPorFormaPago(
                fechaInicio,
                fechaFin,
                idDispensador,
                idTipoAutoservicio
            );

            dashboard.VentasPorDispensador = ObtenerVentasPorDispensador(
                fechaInicio,
                fechaFin,
                idProducto,
                idTipoAutoservicio
            );

            return dashboard;
        }

        // Tipo de transaccion "Autoservicio": su id cambia entre bases (20 en NSX Prime), asi que se busca por nombre; 23 si no se encuentra
        private int ObtenerIdTipoTransaccionAutoservicio()
        {
            try
            {
                using var conn = _conexion.CrearConexion();
                using var cmd = new SqlCommand("SELECT TOP 1 Pk_IdTipoTransaccion FROM dbo.TipoTransaccion WHERE Nombre = 'Autoservicio'", conn);
                conn.Open();
                object valor = cmd.ExecuteScalar();
                if (valor != null && valor != DBNull.Value)
                    return Convert.ToInt32(valor);
            }
            catch (Exception)
            {
                // sin la tabla se mantiene el valor historico
            }
            return 23;
        }

        private static readonly string[] ProgramasFidelidadReporte = { "", "PuntosColombia", "ViveTerpel", "Commodo", "Local", "Leal" };

        // Ventas del rango con canal, vendedor, cliente, formas de pago y fidelizacion, para que el reporte filtre y cruce en pantalla.
        // Se adapta a la base (NSX Prime o NSX2): lo que no exista (turnos, dispositivos, fidelidad) simplemente no se informa.
        public VentasReporteResponseModel ObtenerVentasReporte(DateTime fechaInicio, DateTime fechaFin, int maximo = 20000)
        {
            if (fechaFin < fechaInicio)
                throw new Exception("La fecha fin no puede ser menor a la fecha inicio");

            var respuesta = new VentasReporteResponseModel();

            using var conn = _conexion.CrearConexion();
            conn.Open();

            bool hayTurnos, hayMac, hayDispositivos, hayHibrido, hayProgramacion, hayFidelidad, hayFidelidadPrograma, hayTipoTransaccion;
            using (var cmdFlags = new SqlCommand(@"
                SELECT
                    CASE WHEN OBJECT_ID('Turnos.Turno','U') IS NOT NULL AND OBJECT_ID('Turnos.Islero','U') IS NOT NULL
                          AND COL_LENGTH('DetalleVentaCombustible','Fk_IdTurno') IS NOT NULL THEN 1 ELSE 0 END,
                    CASE WHEN COL_LENGTH('Turnos.Turno','MacTerminal') IS NOT NULL THEN 1 ELSE 0 END,
                    CASE WHEN OBJECT_ID('Autoservice.Dispositivo','U') IS NOT NULL THEN 1 ELSE 0 END,
                    CASE WHEN COL_LENGTH('Autoservice.Dispositivo','ModoHibrido') IS NOT NULL THEN 1 ELSE 0 END,
                    CASE WHEN OBJECT_ID('dbo.DispensadorPosicionProgramacion','U') IS NOT NULL
                          AND OBJECT_ID('dbo.Cuenta','U') IS NOT NULL AND OBJECT_ID('dbo.Empresa','U') IS NOT NULL THEN 1 ELSE 0 END,
                    CASE WHEN OBJECT_ID('Fidelidad.VentaFidelizada','U') IS NOT NULL THEN 1 ELSE 0 END,
                    CASE WHEN COL_LENGTH('Fidelidad.VentaFidelizada','Fk_IdFidelidad') IS NOT NULL THEN 1 ELSE 0 END,
                    CASE WHEN OBJECT_ID('dbo.TipoTransaccion','U') IS NOT NULL THEN 1 ELSE 0 END", conn))
            using (var drFlags = cmdFlags.ExecuteReader())
            {
                drFlags.Read();
                hayTurnos = drFlags.GetInt32(0) == 1;
                hayMac = hayTurnos && drFlags.GetInt32(1) == 1;
                hayDispositivos = drFlags.GetInt32(2) == 1;
                hayHibrido = hayDispositivos && drFlags.GetInt32(3) == 1;
                hayProgramacion = drFlags.GetInt32(4) == 1;
                hayFidelidad = drFlags.GetInt32(5) == 1;
                hayFidelidadPrograma = hayFidelidad && drFlags.GetInt32(6) == 1;
                hayTipoTransaccion = drFlags.GetInt32(7) == 1;
            }

            // Canal: Autoservicio = tipo de transaccion "Autoservicio" o turno abierto desde un dispositivo del autoservicio (MAC);
            // Vendedor = vende en un dispositivo hibrido con un turno de otra isla; Tradicional = el resto
            string condAutoservicio = "0 = 1";
            if (hayTipoTransaccion)
                condAutoservicio = "V.Fk_IdTipoTransaccion IN (SELECT Pk_IdTipoTransaccion FROM dbo.TipoTransaccion WHERE Nombre = 'Autoservicio')";
            if (hayMac && hayDispositivos)
                condAutoservicio = $"({condAutoservicio} OR (T.MacTerminal IS NOT NULL AND EXISTS (SELECT 1 FROM Autoservice.Dispositivo DD WHERE DD.Identificador = T.MacTerminal)))";

            string condVendedor = (hayTurnos && hayHibrido)
                ? "(DISP.ModoHibrido = 1 AND T.Fk_IdIsla IS NOT NULL AND T.Fk_IdIsla <> DP.Fk_IdIsla)"
                : "0 = 1";

            string joinTurno = hayTurnos
                ? @"LEFT JOIN Turnos.Turno T ON T.Pk_IdTurno = DV.Fk_IdTurno
                    LEFT JOIN Turnos.Islero I ON I.Pk_IdIslero = T.Fk_IdIslero"
                : "";
            string campoIslero = hayTurnos ? "I.Pk_IdIslero AS IdIslero, LTRIM(RTRIM(ISNULL(I.Nombres,'') + ' ' + ISNULL(I.Apellidos,''))) AS Vendedor" : "CAST(NULL AS int) AS IdIslero, CAST(NULL AS nvarchar(150)) AS Vendedor";
            if (!hayTurnos)
            {
                // sin turnos T no existe: las condiciones que lo usan ya quedaron en "0 = 1"
                condAutoservicio = hayTipoTransaccion
                    ? "V.Fk_IdTipoTransaccion IN (SELECT Pk_IdTipoTransaccion FROM dbo.TipoTransaccion WHERE Nombre = 'Autoservicio')"
                    : "0 = 1";
            }

            string joinDispositivo = hayDispositivos
                ? $"OUTER APPLY (SELECT TOP 1 {(hayHibrido ? "D2.ModoHibrido" : "CAST(0 AS bit)")} AS ModoHibrido FROM Autoservice.Dispositivo D2 WHERE D2.IdDispensador = DP.Fk_IdDispensador AND D2.Activo = 1) DISP"
                : "OUTER APPLY (SELECT CAST(0 AS bit) AS ModoHibrido) DISP";

            // Una sola agregacion de las programaciones del periodo (la tabla es grande y no tiene indice por venta,
            // asi que buscarla venta por venta agota el tiempo)
            string joinProgramacion = hayProgramacion
                ? @"LEFT JOIN (SELECT PR.Fk_IdVenta AS IdVenta, MAX(PR.Placa) AS Placa, MAX(C.Nombre) AS Cuenta, MAX(E.RazonSocial) AS Empresa
                               FROM dbo.DispensadorPosicionProgramacion PR
                               LEFT JOIN dbo.Cuenta C ON C.Pk_IdCuenta = PR.Fk_IdCuenta
                               LEFT JOIN dbo.Empresa E ON E.Pk_IdEmpresa = C.Fk_IdEmpresa
                               WHERE PR.Fk_IdVenta IS NOT NULL AND PR.FechaInicial >= @FechaDesde
                               GROUP BY PR.Fk_IdVenta) PRG ON PRG.IdVenta = V.Pk_IdVenta"
                : "OUTER APPLY (SELECT CAST(NULL AS nvarchar(20)) AS Placa, CAST(NULL AS nvarchar(100)) AS Cuenta, CAST(NULL AS nvarchar(100)) AS Empresa) PRG";

            string joinFidelidad = hayFidelidad
                ? $@"OUTER APPLY (SELECT TOP 1 1 AS Existe, {(hayFidelidadPrograma ? "VF.Fk_IdFidelidad" : "CAST(NULL AS int)")} AS IdFidelidad
                                 FROM Fidelidad.VentaFidelizada VF
                                 WHERE VF.Fk_IdVenta = V.Pk_IdVenta AND VF.Fk_IdTipoTransaccion = 1 AND VF.Fk_IdEstadoTransaccion = 2
                                   AND (VF.CodigoError IS NULL OR VF.CodigoError = '')
                                 ORDER BY VF.Pk_IdFidelizacion DESC) FID"
                : "OUTER APPLY (SELECT CAST(NULL AS int) AS Existe, CAST(NULL AS int) AS IdFidelidad) FID";

            var porVenta = new Dictionary<int, VentaReporteModel>();
            using (var cmd = new SqlCommand($@"
                SELECT TOP (@Max)
                    V.Pk_IdVenta AS IdVenta, V.FechaFinal AS Fecha, V.ValorTotal AS Total, V.CantidadTotal AS Volumen,
                    V.Fk_IdTipoTransaccion AS TipoTransaccion,
                    DV.Fk_IdProducto AS IdProducto, P.Nombre AS Producto,
                    DP.Pk_IdPosicion AS IdPosicion, DP.Fk_IdDispensador AS IdDispensador,
                    {campoIslero},
                    CASE WHEN {condAutoservicio} THEN 'Autoservicio'
                         WHEN {condVendedor} THEN 'Vendedor'
                         ELSE 'Tradicional' END AS Canal,
                    PRG.Placa, PRG.Cuenta, PRG.Empresa,
                    FID.Existe AS Fidelizada, FID.IdFidelidad
                FROM Venta V
                INNER JOIN DetalleVentaCombustible DV ON DV.Fk_IdVenta = V.Pk_IdVenta
                INNER JOIN DispensadorPosicion DP ON DP.Pk_IdPosicion = DV.Fk_IdPosicion
                LEFT JOIN Producto P ON P.Pk_IdProducto = DV.Fk_IdProducto
                {joinTurno}
                {joinDispositivo}
                {joinProgramacion}
                {joinFidelidad}
                WHERE V.FechaFinal BETWEEN @FechaInicio AND @FechaFin
                ORDER BY V.FechaFinal DESC", conn))
            {
                cmd.CommandTimeout = 120;
                cmd.Parameters.AddWithValue("@Max", maximo + 1);
                cmd.Parameters.AddWithValue("@FechaInicio", fechaInicio);
                cmd.Parameters.AddWithValue("@FechaFin", fechaFin);
                cmd.Parameters.AddWithValue("@FechaDesde", fechaInicio.AddDays(-2));

                using var dr = cmd.ExecuteReader();
                while (dr.Read())
                {
                    int idVenta = Convert.ToInt32(dr["IdVenta"]);
                    if (porVenta.ContainsKey(idVenta))
                        continue;

                    int? idFidelidad = dr["IdFidelidad"] == DBNull.Value ? null : Convert.ToInt32(dr["IdFidelidad"]);
                    var venta = new VentaReporteModel
                    {
                        IdVenta = idVenta,
                        Fecha = Convert.ToDateTime(dr["Fecha"]),
                        Total = Convert.ToDecimal(dr["Total"]),
                        Volumen = Convert.ToDecimal(dr["Volumen"]),
                        TipoTransaccion = Convert.ToInt32(dr["TipoTransaccion"]),
                        IdProducto = dr["IdProducto"] == DBNull.Value ? 0 : Convert.ToInt32(dr["IdProducto"]),
                        Producto = dr["Producto"] as string,
                        IdPosicion = Convert.ToInt32(dr["IdPosicion"]),
                        IdDispensador = Convert.ToInt32(dr["IdDispensador"]),
                        IdIslero = dr["IdIslero"] == DBNull.Value ? null : Convert.ToInt32(dr["IdIslero"]),
                        Vendedor = (dr["Vendedor"] as string)?.Trim(),
                        Canal = (string)dr["Canal"],
                        Placa = dr["Placa"] as string,
                        Cuenta = dr["Cuenta"] as string,
                        Empresa = dr["Empresa"] as string,
                        Fidelizada = dr["Fidelizada"] != DBNull.Value,
                        IdFidelidad = idFidelidad,
                        Programa = idFidelidad.HasValue && idFidelidad.Value >= 1 && idFidelidad.Value < ProgramasFidelidadReporte.Length
                            ? ProgramasFidelidadReporte[idFidelidad.Value]
                            : null
                    };
                    if (string.IsNullOrWhiteSpace(venta.Vendedor)) venta.Vendedor = null;

                    if (porVenta.Count >= maximo)
                    {
                        respuesta.Truncado = true;
                        break;
                    }
                    porVenta[idVenta] = venta;
                }
            }

            if (porVenta.Count > 0)
            {
                string joinDFP = _gne
                    ? "INNER JOIN FormaPago.DetalleFormaPago DFP ON V.Pk_IdVenta = DFP.Fk_IdVenta"
                    : @"INNER JOIN FormaPago.DetalleFormaPago DFP
                            ON V.Pk_IdVenta = DFP.ConsecutivoReferenciaTabla AND DFP.Fk_IdTipoCompra = 1";

                using var cmdPagos = new SqlCommand($@"
                    SELECT V.Pk_IdVenta AS IdVenta, FP.NombreFormaPago AS Nombre, ISNULL(SUM(DFP.Valor), 0) AS Valor
                    FROM Venta V
                    {joinDFP}
                    INNER JOIN FormaPago.FormaPago FP ON DFP.Fk_IdFormaPago = FP.Pk_IdFormaPago
                    WHERE V.FechaFinal BETWEEN @FechaInicio AND @FechaFin
                    GROUP BY V.Pk_IdVenta, FP.NombreFormaPago", conn);
                cmdPagos.Parameters.AddWithValue("@FechaInicio", fechaInicio);
                cmdPagos.Parameters.AddWithValue("@FechaFin", fechaFin);

                try
                {
                    using var drPagos = cmdPagos.ExecuteReader();
                    while (drPagos.Read())
                    {
                        if (porVenta.TryGetValue(Convert.ToInt32(drPagos["IdVenta"]), out var venta))
                        {
                            venta.FormasPago.Add(new FormaPagoVentaReporteModel
                            {
                                Nombre = drPagos["Nombre"].ToString() ?? "",
                                Valor = Convert.ToDecimal(drPagos["Valor"])
                            });
                        }
                    }
                }
                catch (SqlException)
                {
                    // sin tablas de formas de pago el reporte sigue, todo se muestra como efectivo / a cuenta
                }

                // Lo que no esta en formas de pago: a cuenta si la venta tiene cuenta, efectivo si no
                foreach (var venta in porVenta.Values)
                {
                    decimal resto = venta.Total - venta.FormasPago.Sum(f => f.Valor);
                    if (resto > 0.5m)
                    {
                        venta.FormasPago.Add(new FormaPagoVentaReporteModel
                        {
                            Nombre = string.IsNullOrEmpty(venta.Cuenta) ? "Efectivo" : "A cuenta",
                            Valor = resto
                        });
                    }
                }
            }

            respuesta.Ventas = porVenta.Values.OrderByDescending(v => v.Fecha).ToList();
            return respuesta;
        }

        private List<VentaDispensadorModel> ObtenerVentasPorDispensador(DateTime fechaInicio, DateTime fechaFin, int? idProducto = null, int? idTipoTransaccion = null)
        {
            List<VentaDispensadorModel> ventas = new List<VentaDispensadorModel>();

            using var conn = _conexion.CrearConexion();
            using var cmd = new SqlCommand();

            cmd.Connection = conn;

            cmd.CommandText = @"
                                SELECT
                                    D.Pk_IdDispensador AS IdDispensador,
                                    ISNULL(SUM(V.ValorTotal), 0) AS Total
                                FROM Venta V

                                INNER JOIN DetalleVentaCombustible DV
                                    ON V.Pk_IdVenta = DV.Fk_IdVenta

                                INNER JOIN DispensadorPosicion DP
                                    ON DV.Fk_IdPosicion = DP.Pk_IdPosicion

                                INNER JOIN Dispensador D
                                    ON DP.Fk_IdDispensador = D.Pk_IdDispensador

                                WHERE
                                    V.FechaFinal BETWEEN @FechaInicio AND @FechaFin

                                    AND (
                                        @IdTipoTransaccion IS NULL
                                        OR V.Fk_IdTipoTransaccion = @IdTipoTransaccion
                                    )

                                    AND (
                                        @IdProducto IS NULL
                                        OR DV.Fk_IdProducto = @IdProducto
                                    )

                                GROUP BY D.Pk_IdDispensador
                                ORDER BY Total DESC
                            ";

            cmd.Parameters.AddWithValue("@FechaInicio", fechaInicio);
            cmd.Parameters.AddWithValue("@FechaFin", fechaFin);

            if (idProducto.HasValue)
                cmd.Parameters.AddWithValue("@IdProducto", idProducto.Value);
            else
                cmd.Parameters.AddWithValue("@IdProducto", DBNull.Value);

            if (idTipoTransaccion.HasValue)
                cmd.Parameters.AddWithValue(
                    "@IdTipoTransaccion",
                    idTipoTransaccion.Value);
            else
                cmd.Parameters.AddWithValue(
                    "@IdTipoTransaccion",
                    DBNull.Value);

            try
            {
                conn.Open();

                using var dr = cmd.ExecuteReader();

                while (dr.Read())
                {
                    ventas.Add(new VentaDispensadorModel
                    {
                        IdDispensador = Convert.ToInt32(dr["IdDispensador"]),
                        Total = Convert.ToDecimal(dr["Total"])
                    });
                }
            }
            catch (Exception)
            {
                throw;
            }

            return ventas;
        }

        private List<VentaFormaPagoModel> ObtenerVentasPorFormaPago(DateTime fechaInicio, DateTime fechaFin, int? idDispensador = null, int? idTipoTransaccion = null)
        {
            List<VentaFormaPagoModel> ventas = new List<VentaFormaPagoModel>();
            using var conn = _conexion.CrearConexion();
            using var cmd = new SqlCommand();
            cmd.Connection = conn;

            string joinDFP = _gne
                ? "INNER JOIN FormaPago.DetalleFormaPago DFP ON V.Pk_IdVenta = DFP.Fk_IdVenta"
                : @"INNER JOIN FormaPago.DetalleFormaPago DFP
                            ON V.Pk_IdVenta = DFP.ConsecutivoReferenciaTabla
                            AND DFP.Fk_IdTipoCompra = 1";

            cmd.CommandText = $@"
                        SELECT
	                        FP.Pk_IdFormaPago,
                            FP.NombreFormaPago,
                            ISNULL(SUM(DFP.Valor), 0) AS Total
                        FROM Venta V
                        {joinDFP}
                        INNER JOIN FormaPago.FormaPago FP
                            ON DFP.Fk_IdFormaPago = FP.Pk_IdFormaPago
                        LEFT JOIN DetalleVentaCombustible DV
                            ON V.Pk_IdVenta = DV.Fk_IdVenta
                        LEFT JOIN DispensadorPosicion DP
                            ON DV.Fk_IdPosicion = DP.Pk_IdPosicion
                        LEFT JOIN Dispensador D
                            ON DP.Fk_IdDispensador = D.Pk_IdDispensador
                        WHERE
                            V.FechaFinal BETWEEN @FechaInicio AND @FechaFin
                            AND (
                                @IdTipoTransaccion IS NULL
                                OR V.Fk_IdTipoTransaccion = @IdTipoTransaccion
                            )
                            AND (
                                @IdDispensador IS NULL
                                OR D.Pk_IdDispensador = @IdDispensador
                            )
                        GROUP BY FP.Pk_IdFormaPago, FP.NombreFormaPago
                        ORDER BY Total DESC
                    ";
            cmd.Parameters.AddWithValue("@FechaInicio", fechaInicio);
            cmd.Parameters.AddWithValue("@FechaFin", fechaFin);
            if (idDispensador.HasValue)
                cmd.Parameters.AddWithValue("@IdDispensador", idDispensador.Value);
            else
                cmd.Parameters.AddWithValue("@IdDispensador", DBNull.Value);
            if (idTipoTransaccion.HasValue)
                cmd.Parameters.AddWithValue("@IdTipoTransaccion", idTipoTransaccion.Value);
            else
                cmd.Parameters.AddWithValue("@IdTipoTransaccion", DBNull.Value);
            try
            {
                conn.Open();
                using var dr = cmd.ExecuteReader();
                while (dr.Read())
                {
                    ventas.Add(new VentaFormaPagoModel
                    {
                        IdFormaPago = Convert.ToInt32(dr["Pk_IdFormaPago"]),
                        FormaPago = dr["NombreFormaPago"].ToString(),
                        Total = Convert.ToDecimal(dr["Total"])
                    });
                }
            }
            catch (Exception)
            {
                throw;
            }
            return ventas;
        }

        private List<VentaPorProductoModel> ObtenerVentasPorProducto(DateTime fechaInicio, DateTime fechaFin, int? idTipoTransaccion = null)
        {
            List<VentaPorProductoModel> ventas = new();

            using var conn = _conexion.CrearConexion();
            using var cmd = new SqlCommand();

            cmd.Connection = conn;

            cmd.CommandText = @"
                                SELECT
                                    P.Pk_IdProducto AS IdProducto,
                                    P.Nombre AS NombreProducto,

                                    ISNULL(SUM(V.CantidadTotal), 0) AS Volumen,

                                    ISNULL(SUM(V.ValorTotal), 0) AS Total

                                FROM Venta V

                                INNER JOIN DetalleVentaCombustible DVC
                                    ON V.Pk_IdVenta = DVC.Fk_IdVenta

                                INNER JOIN Producto P
                                    ON DVC.Fk_IdProducto = P.Pk_IdProducto

                                WHERE
                                    V.FechaFinal BETWEEN @FechaInicio AND @FechaFin

                                    AND (
                                        @IdTipoTransaccion IS NULL
                                        OR V.Fk_IdTipoTransaccion = @IdTipoTransaccion
                                    )

                                GROUP BY
                                    P.Pk_IdProducto,
                                    P.Nombre

                                ORDER BY
                                    Total DESC
                            ";

            cmd.Parameters.AddWithValue("@FechaInicio", fechaInicio);
            cmd.Parameters.AddWithValue("@FechaFin", fechaFin);

            if (idTipoTransaccion.HasValue)
                cmd.Parameters.AddWithValue(
                    "@IdTipoTransaccion",
                    idTipoTransaccion.Value);
            else
                cmd.Parameters.AddWithValue(
                    "@IdTipoTransaccion",
                    DBNull.Value);

            try
            {
                conn.Open();

                using var dr = cmd.ExecuteReader();

                while (dr.Read())
                {
                    ventas.Add(new VentaPorProductoModel
                    {
                        IdProducto = Convert.ToInt32(dr["IdProducto"]),
                        NombreProducto = dr["NombreProducto"].ToString(),
                        Volumen = Convert.ToDecimal(dr["Volumen"]),
                        Total = Convert.ToDecimal(dr["Total"])
                    });
                }
            }
            catch (Exception)
            {
                throw;
            }

            return ventas;
        }

        public DashboardKPIModel ObtenerKPIs(DateTime fechaInicio, DateTime fechaFin, int? idDispensador, int? idProducto, int? idTipoTransaccion)
        {
            DashboardKPIModel kpi = new DashboardKPIModel();

            using var conn = _conexion.CrearConexion();
            using var cmd = new SqlCommand();

            cmd.Connection = conn;

            cmd.CommandText = @"
                                SELECT
                                    ISNULL(SUM(V.ValorTotal), 0) AS TotalVentas,
                                    ISNULL(SUM(V.CantidadTotal), 0) AS TotalVolumen,
                                    COUNT(DISTINCT V.Pk_IdVenta) AS TotalTransacciones,
                                    ISNULL(AVG(V.ValorTotal), 0) AS TicketPromedio
                                FROM [Venta] V
                                INNER JOIN DetalleVentaCombustible DV
                                    ON V.Pk_IdVenta = DV.Fk_IdVenta
                                INNER JOIN DispensadorPosicion DP
                                    ON DV.Fk_IdPosicion = DP.Pk_IdPosicion
                                INNER JOIN Dispensador D
                                    ON DP.Fk_IdDispensador = D.Pk_IdDispensador
                                WHERE
                                    V.FechaFinal BETWEEN @FechaInicio AND @FechaFin
                                    AND (@IdTipoTransaccion IS NULL
                                         OR V.Fk_IdTipoTransaccion = @IdTipoTransaccion)
                                    AND (@IdDispensador IS NULL
                                         OR D.Pk_IdDispensador = @IdDispensador)
                                    AND (@IdProducto IS NULL
                                         OR DV.Fk_IdProducto = @IdProducto)
                            ";

            cmd.Parameters.AddWithValue("@FechaInicio", fechaInicio);
            cmd.Parameters.AddWithValue("@FechaFin", fechaFin);
            cmd.Parameters.AddWithValue("@IdDispensador", (object?)idDispensador ?? DBNull.Value);
            cmd.Parameters.AddWithValue("@IdProducto", (object?)idProducto ?? DBNull.Value);
            cmd.Parameters.AddWithValue("@IdTipoTransaccion", (object?)idTipoTransaccion ?? DBNull.Value);

            try
            {
                conn.Open();

                using var dr = cmd.ExecuteReader();

                if (dr.Read())
                {
                    kpi.TotalVentas = Convert.ToDecimal(dr["TotalVentas"]);
                    kpi.TotalVolumen = Convert.ToDecimal(dr["TotalVolumen"]);
                    kpi.TotalTransacciones = Convert.ToInt32(dr["TotalTransacciones"]);
                    kpi.TicketPromedio = Convert.ToDecimal(dr["TicketPromedio"]);
                }
            }
            catch (Exception)
            {
                throw;
            }

            return kpi;
        }

        private ParticipacionModel ObtenerParticipacion(DateTime fechaInicio, DateTime fechaFin, int idTipoAutoservicio)
        {
            ParticipacionModel participacion = new ParticipacionModel();

            using var conn = _conexion.CrearConexion();
            using var cmd = new SqlCommand();

            cmd.Connection = conn;

            cmd.CommandText = @"
                                SELECT
                                    ISNULL(SUM(V.ValorTotal), 0) AS VentasEDS,

                                    ISNULL(SUM(CASE
                                        WHEN V.Fk_IdTipoTransaccion = @IdTipoAutoservicio
                                        THEN V.ValorTotal
                                        ELSE 0
                                    END), 0) AS VentasAutoservicio,

                                    ISNULL(SUM(CASE
                                        WHEN V.Fk_IdTipoTransaccion <> @IdTipoAutoservicio
                                        THEN V.ValorTotal
                                        ELSE 0
                                    END), 0) AS VentasTradicional

                                FROM Venta V
                                WHERE V.FechaFinal BETWEEN @FechaInicio AND @FechaFin
                            ";

            cmd.Parameters.AddWithValue("@FechaInicio", fechaInicio);
            cmd.Parameters.AddWithValue("@FechaFin", fechaFin);
            cmd.Parameters.AddWithValue("@IdTipoAutoservicio", idTipoAutoservicio);

            try
            {
                conn.Open();

                using var dr = cmd.ExecuteReader();

                if (dr.Read())
                {
                    participacion.VentasEDS =
                        Convert.ToDecimal(dr["VentasEDS"]);

                    participacion.VentasAutoservicio =
                        Convert.ToDecimal(dr["VentasAutoservicio"]);

                    participacion.VentasTradicional =
                        Convert.ToDecimal(dr["VentasTradicional"]);

                    participacion.PorcentajeAutoservicio =
                        participacion.VentasEDS > 0
                            ? Math.Round(
                                (participacion.VentasAutoservicio /
                                 participacion.VentasEDS) * 100,
                                2)
                            : 0;
                }
            }
            catch (Exception)
            {
                throw;
            }

            return participacion;
        }

        private List<VentaPorDiaModel> ObtenerVentasPorDia(DateTime fechaInicio,DateTime fechaFin, int idTipoAutoservicio)
        {
            List<VentaPorDiaModel> ventas = new();

            using var conn = _conexion.CrearConexion();
            using var cmd = new SqlCommand();

            cmd.Connection = conn;

            cmd.CommandText = @"
                                SELECT
                                    CAST(V.FechaFinal AS DATE) AS Fecha,

                                    ISNULL(SUM(
                                        CASE
                                            WHEN V.Fk_IdTipoTransaccion = @IdTipoAutoservicio
                                            THEN V.ValorTotal
                                            ELSE 0
                                        END
                                    ), 0) AS VentasAutoservicio,

                                    ISNULL(SUM(
                                        CASE
                                            WHEN V.Fk_IdTipoTransaccion <> @IdTipoAutoservicio
                                            THEN V.ValorTotal
                                            ELSE 0
                                        END
                                    ), 0) AS VentasTradicional,

                                    ISNULL(SUM(V.ValorTotal), 0) AS VentasTotales

                                FROM Venta V
                                WHERE
                                    V.FechaFinal BETWEEN @FechaInicio AND @FechaFin

                                GROUP BY CAST(V.FechaFinal AS DATE)

                                ORDER BY Fecha
                            ";

            cmd.Parameters.AddWithValue("@FechaInicio", fechaInicio);
            cmd.Parameters.AddWithValue("@FechaFin", fechaFin);
            cmd.Parameters.AddWithValue("@IdTipoAutoservicio", idTipoAutoservicio);

            try
            {
                conn.Open();

                using var dr = cmd.ExecuteReader();

                while (dr.Read())
                {
                    ventas.Add(new VentaPorDiaModel
                    {
                        Fecha = Convert.ToDateTime(dr["Fecha"]),
                        VentasAutoservicio = Convert.ToDecimal(dr["VentasAutoservicio"]),
                        VentasTradicional = Convert.ToDecimal(dr["VentasTradicional"]),
                        VentasTotales = Convert.ToDecimal(dr["VentasTotales"])
                    });
                }
            }
            catch (Exception)
            {
                throw;
            }

            return ventas;
        }

        public int ObtenerIdPosicionByIdentificador(string identificador)
        {
            int idPosicion = 0;
            using var conn = _conexion.CrearConexion();
            using var co = new SqlCommand();
            co.Connection = conn;
            try
            {
                co.CommandText = @$"SELECT TOP 1 Fk_IdPosicionApertura FROM Turnos.Turno
                                          WHERE MacTerminal = '{identificador}' AND Fk_IdEstadoTurno = 1
                                          ORDER BY 1 DESC";
                conn.Open();
                using SqlDataReader dr = co.ExecuteReader();
                while (dr.Read())
                {
                    idPosicion = (int)dr["Fk_IdPosicionApertura"];
                }
            }
            catch (Exception)
            {
                throw;
            }
            finally
            {
                conn.Close();
            }
            return idPosicion;
        }

        public int ObtenerIdPosicionVenta(int idVenta)
        {
            using var conn = _conexion.CrearConexion();
            using var cmd = new SqlCommand(
                "SELECT TOP 1 Fk_IdPosicion FROM DetalleVentaCombustible WHERE Fk_IdVenta = @IdVenta", conn);
            cmd.Parameters.AddWithValue("@IdVenta", idVenta);
            conn.Open();
            var r = cmd.ExecuteScalar();
            return r == null || r == DBNull.Value ? 0 : Convert.ToInt32(r);
        }

        public int ObtenerIdPosicion()
        {
            int idPosicion = 0;

            using var conn = _conexion.CrearConexion();
            using var cmd = new SqlCommand();

            cmd.Connection = conn;
            cmd.CommandText = @"SELECT TOP 1 dp.Pk_IdPosicion
                                FROM DispensadorPosicion dp
                                INNER JOIN Autoservice.Dispositivo d
                                    ON d.IdDispensador = dp.Fk_IdDispensador
                                WHERE d.Activo = 1
                                  AND dp.Activo = 1
                                ORDER BY dp.Pk_IdPosicion";

            conn.Open();

            using var dr = cmd.ExecuteReader();

            while (dr.Read())
            {
                idPosicion = Convert.ToInt32(dr["Pk_IdPosicion"]);
            }

            return idPosicion;
        }

        public List<int> ObtenerIdsPosicionByIdentificador(string identificador)
        {
            List<int> idsPosicion = new();

            using var conn = _conexion.CrearConexion();
            using var cmd = new SqlCommand();

            cmd.Connection = conn;
            cmd.CommandText = @"SELECT dp.Pk_IdPosicion
                                FROM DispensadorPosicion dp
                                INNER JOIN Autoservice.Dispositivo d
                                    ON d.IdDispensador = dp.Fk_IdDispensador
                                WHERE d.Activo = 1
                                  AND dp.Activo = 1
                                  AND d.Identificador = @Identificador";

            cmd.Parameters.AddWithValue("@Identificador", identificador);

            conn.Open();

            using var dr = cmd.ExecuteReader();

            while (dr.Read())
            {
                idsPosicion.Add(Convert.ToInt32(dr["Pk_IdPosicion"]));
            }

            return idsPosicion;
        }

        public bool MarcarImpresionPendiente(int idVenta)
        {
            using var conn = _conexion.CrearConexion();
            using var cmd = new SqlCommand();
            try
            {
                cmd.Connection = conn;
                cmd.CommandText = @"
            UPDATE ImpresionPosicion
            SET Impreso = 0
            WHERE ConsecutivoVenta = @IdVenta";

                cmd.Parameters.AddWithValue("@IdVenta", idVenta);
                conn.Open();
                int filas = cmd.ExecuteNonQuery();
                return filas > 0;
            }
            catch (Exception ex)
            {
                return false;
            }
        }

    }
}
