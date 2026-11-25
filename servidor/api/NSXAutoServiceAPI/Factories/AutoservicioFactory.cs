using Microsoft.Extensions.Caching.Memory;
using NSXAutoservice.Core;
using NSXAutoServiceAPI.Services.Implementations;
using NSXAutoServiceAPI.Services.Interfaces;

namespace NSXAutoServiceAPI.Factories
{
    public class AutoservicioFactory : IAutoservicioFactory
    {
        private readonly IServiceProvider _provider;
        private readonly Consultas _consultas;
        private readonly IMemoryCache _cache;

        public AutoservicioFactory(IServiceProvider provider, Consultas consultas, IMemoryCache cache)
        {
            _provider = provider;
            _consultas = consultas;
            _cache = cache;
        }

        public IAutoservicioService CrearServicio()
        {
            if (!_cache.TryGetValue("SISTEMA", out string sistema))
            {
                sistema = _consultas.ObtenerConfiguracionAutoservice("Sistema");

                _cache.Set("SISTEMA", sistema, new MemoryCacheEntryOptions
                {
                    AbsoluteExpirationRelativeToNow = TimeSpan.FromHours(12)
                    // o incluso sin expiración si quieres
                });
            }

            return sistema.ToUpper() switch
            {
                "NSX" => _provider.GetRequiredService<NSXAutoservicioService>(),
                "GNESYS" => _provider.GetRequiredService<GNESYSAutoservicioService>(),
                _ => throw new Exception("Sistema no soportado")
            };
        }
    }
}
