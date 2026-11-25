using NSXAutoservice.Models;
using NSXAutoservice.Models.Request;
using NSXAutoservice.Models.Response;

namespace NSXAutoServiceAPI.Services.Interfaces
{
    public interface IAutoservicioService
    {
        ResultadoOperacion<int> CrearPreset(PresetRequest preset);
        ResultadoOperacion<int> CrearPresetVendedor(PresetVendedorRequest preset);
        ResultadoOperacion<object> CancelarPresetVendedor(CancelarPresetVendedorRequest request);
        ResultadoOperacion<object> LeerIdentificador(LeerIdentificadorRequest request);
        ResultadoOperacion<object> AutorizarCliente(AutorizarClienteRequest request);
        bool CancelarPreset(PresetRequest preset);
        ResultadoOperacion<object> ObtenerEstadoPreset(int idPreset);
        List<PreciosModel> ObtenerPrecios();
        ResultadoOperacion<object> GenerarFactura(FacturacionRequest request);
        ResultadoOperacion<ClienteFEModel> ConsultarClienteFE(string documento);
        ResultadoOperacion<object> ImprimirVenta(int idVenta);
        ResultadoOperacion<VendedorModel> ValidarVendedor(string documento, string password);
        ResultadoOperacion<object> AbrirTurno(TurnoRequest request);
        ResultadoOperacion<object> CerrarTurno(TurnoRequest request);
        ResultadoOperacion<object> ValidarClienteFidelidad(FidelidadConsultarRequest request);
        ResultadoOperacion<object> AcumularFidelidad(FidelidadAcumularRequest request);
        ResultadoOperacion<object> ObtenerEstado(int idPosicion);
    }
}
