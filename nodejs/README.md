# NSX2API SERVICE

Servicio Node.js para integracion con NSX y PostgreSQL.

## Arquitectura

La logica activa vive en `src/`:

- `src/app.js`: configuracion de Express, middlewares y rutas.
- `src/server.js`: arranque del servidor HTTP.
- `src/config/`: entorno, logger y conexion a PostgreSQL.
- `src/controllers/`: capa HTTP.
- `src/services/`: logica de negocio.
- `src/repositories/`: acceso a datos y consultas SQL.
- `src/middlewares/`: autenticacion, errores y 404.
- `src/sockets/`: Socket.IO y listener de PostgreSQL.
- `src/utils/`: utilidades comunes como el cliente HTTP y el wrapper `asyncHandler`.

La raiz conserva solo el bootstrap (`app.js`) y algunas utilidades independientes que no forman parte del flujo principal, como `sockets/client.js` y los helpers JWT.

## Errores

Se usa `AppError` para responder con codigos consistentes:

- `400` para validaciones.
- `404` para recursos inexistentes.
- `409` para conflictos.
- `502` para fallos de NSX o infraestructura externa.

El middleware central en `src/middlewares/error-handler.js` convierte esas excepciones en respuestas JSON uniformes.

## Base de datos

La conexion a PostgreSQL esta centralizada en `src/config/postgres.js` con:

- pool configurable por entorno.
- timeouts de conexion y query.
- manejo central de errores del pool.

## Logging

`src/config/logger.js` centraliza la salida de logs del proyecto. La aplicacion usa ese logger en HTTP, PostgreSQL y sockets.

## Pruebas

Ejecuta:

```bash
npm test
```

Las pruebas basicas cubren:

- controllers
- repositories
- sockets
