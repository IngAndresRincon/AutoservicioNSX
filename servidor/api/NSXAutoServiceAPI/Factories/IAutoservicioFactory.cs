using NSXAutoServiceAPI.Services.Interfaces;

namespace NSXAutoServiceAPI.Factories
{
    public interface IAutoservicioFactory
    {
        IAutoservicioService CrearServicio();
    }
}
