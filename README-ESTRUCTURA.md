# Estructura

| Carpeta | Que es |
|---|---|
| `consola/`, `service/`, `terminal/` | Servicios de la Orange |
| `webpage/` | Pagina de gestion (ventas, autorizaciones, aprobar pagos) |
| `servidor/api/` | API .NET del autoservicio |
| `servidor/admin/` | Pagina de configuracion |
| `app/` | App de la tablet (Flutter, gnesys_as) |
| `instalador/` | Instalador del servidor (`Armar-Paquetes.ps1`, luego `Instalar.bat`) |
| `orange/` | Actualizador de la Orange (`actualizador/armar.sh`) y diagnostico |
| `sql/`, `docs/` | Scripts de SQL Server y documentacion |

No se suben claves, `.env`, `appsettings*.json`, respaldos ni la llave de firma. Use los archivos `*.ejemplo`.

## Llaves de la app
En git `app/lib/config/api_config.dart` va sin llaves. Para compilar:
`flutter build apk --dart-define=API_KEY=<llave> --dart-define=SOCKET_API_KEY=<llave>`
(las mismas de `API_KEYS` e `IO_API_KEY` en el `.env` de la Orange).
