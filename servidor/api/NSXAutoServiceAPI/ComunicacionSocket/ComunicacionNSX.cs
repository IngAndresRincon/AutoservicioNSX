using Encripcion.Encrypter;
using System.Net.Sockets;
using System.Net;
using System.Text;
using NSXAutoservice.Core;
using Microsoft.Extensions.Caching.Memory;

namespace NSXAutoServiceAPI.ComunicacionSocket
{
    public class ComunicacionNSX
    {
        private readonly Consultas _consultas;
        private readonly bool _encripcion;
        private readonly string _ip;
        private readonly string _port;

        // Se lee de la base una sola vez y queda en memoria mientras corra el API (evita 2 consultas SQL por comando).
        // Si cambia IPNsxAPI o Sistema, se reinicia el sitio en IIS.
        private static readonly object _configLock = new();
        private static (string Ip, string Port, bool Encripcion)? _config;

        public ComunicacionNSX(Consultas consultas)
        {
            _consultas = consultas;

            if (_config == null)
            {
                lock (_configLock)
                {
                    if (_config == null)
                    {
                        var ip = _consultas.ObtenerConfiguracion("IPNsxAPI").Split('|');
                        if (ip.Length < 2 || string.IsNullOrWhiteSpace(ip[0]) || string.IsNullOrWhiteSpace(ip[1]))
                            throw new Exception("La configuracion 'IPNsxAPI' no esta definida (se espera 'ip|puerto')");

                        string sistema = _consultas.ObtenerConfiguracionAutoservice("Sistema");
                        _config = (ip[0], ip[1], sistema.Equals("NSX", StringComparison.OrdinalIgnoreCase));
                    }
                }
            }

            _ip = _config.Value.Ip;
            _port = _config.Value.Port;
            _encripcion = _config.Value.Encripcion;
        }
        public string EnviarComando(string comando, int timeoutMs = 5000)
        {
            try
            {
                IPAddress ipAd = IPAddress.Parse(_ip);
                int puerto = int.Parse(_port);

                EncriptionHelper enc = new EncriptionHelper();

                using (TcpClient tcpclnt = new TcpClient())
                {
                    // ⏱ Timeout de conexión
                    //_consultas.LogInfo("Enviar comando " +  comando + ipAd + puerto);
                    var result = tcpclnt.BeginConnect(ipAd, puerto, null, null);
                    bool success = result.AsyncWaitHandle.WaitOne(timeoutMs);

                    if (!success)
                        throw new TimeoutException("Timeout al conectar");

                    tcpclnt.EndConnect(result);

                    using (NetworkStream stm = tcpclnt.GetStream())
                    {
                        stm.ReadTimeout = timeoutMs;   // ⏱ Timeout lectura
                        stm.WriteTimeout = timeoutMs;  // ⏱ Timeout escritura

                        string mensaje = _encripcion
                                        ? enc.Encrypt(comando)
                                        : comando;

                        byte[] ba = Encoding.ASCII.GetBytes(mensaje);

                        // ✉️ Enviar
                        stm.Write(ba, 0, ba.Length);

                        // 📥 Recibir
                        byte[] buffer = new byte[500];
                        int bytesLeidos = stm.Read(buffer, 0, buffer.Length);

                        string respuesta = Encoding.ASCII.GetString(buffer, 0, bytesLeidos);
                        return _encripcion
                               ? enc.Decrypt(respuesta)
                               : respuesta;
                    }
                }
            }
            catch (TimeoutException)
            {
                return "E|0|Timeout en la comunicación";
            }
            catch (Exception e)
            {
                return "E|0|Error Envio Comando";
            }
        }
    }
}
