# Endpoints para el modo vendedor (Orange Pi → API de autoservicio)

Para quien publica los servicios en la Orange Pi. La app Flutter (`gnesys_as`) no llama al API de NSX: llama a la Orange Pi, y esta reenvía al API. Todo lo de abajo es del API `NSXAutorserviceAPI`; el cuerpo de las respuestas es siempre el mismo sobre:

```json
{ "success": true, "message": "texto", "data": { }, "errors": null }
```
En error: `success: false`, `message` con el motivo (los errores de negocio de NSX llegan aquí tal cual) y `errors` con una lista cuando son validaciones.

Convenciones: `identificador` es la MAC del dispositivo (12 caracteres). `documento` del vendedor es **numérico**. Los valores en dinero van como número sin separadores (`50000`).

## 1. Al arrancar la pantalla
### `GET api/Mapeo/ObtenerMapeo?identificador={mac}`
Ya existía; se agregaron dos cosas:
- `dispensadores[].hibrido` (bool): si es `true`, la app muestra el acceso de vendedor.
- `formasPagoVendedor[]`: formas de pago que ve el vendedor (distintas de `formasPago`, que son las del autoservicio). Cada una: `idFormaPago`, `idFormaPagoSistema` (en esta lista son iguales), `nombre`, `activo`. Para el vendedor se usa **`idFormaPago`**.

## 2. Login y turno
### `POST api/Turno/ValidarVendedor`
```json
{ "documento": "1234567890", "password": "9012" }
```
`data`: `{ idIslero, cedula, nombre, apellidos, activo }`. 401 si las credenciales son inválidas. Es el único paso donde se pide la contraseña.

### `POST api/Turno/AbrirTurno`
```json
{ "identificador": "123456789012", "idPosicion": 5, "documento": "1234567890", "password": "9012" }
```
Si el vendedor ya tiene un turno abierto, NSX lo reutiliza (no abre otro). `data`: `{ idTurno, posicion, vendedor }`. Se puede llamar siempre justo después del login.

### `POST api/Turno/CerrarTurno`
Mismo cuerpo que `AbrirTurno`. Solo cuando el vendedor elige "Cerrar turno" (cerrar sesión **no** cierra el turno).

## 3. Vender
### `POST api/Preset/PresetVendedor`  *(nuevo)*
```json
{ "identificador": "123456789012", "documento": "1234567890", "idPosicion": 5,
  "numeroManguera": 1, "tipoProgramacion": 2, "valor": 50000, "placa": "ABC123", "km": 12000 }
```
- `tipoProgramacion`: 1 = lleno, 2 = dinero, 3 = volumen. Con `1` el valor no se usa.
- `placa` y `km` opcionales.
- Solo el documento: el API busca al vendedor y usa **su turno abierto**. Sin forma de pago: la venta queda en efectivo.
- `data`: `{ idPreset }`. Errores de negocio (llegan en `message`/`errors`): vendedor no encontrado o inactivo, "El vendedor no tiene un turno abierto", y los de NSX (posición ocupada, otra isla no híbrida, etc.).

### `GET api/Preset/ObtenerEstado?idPosicion={n}`
`data`: `{ estadoSurtidor, dinero, volumen, grado, gradoPreset }`. Valores de `estadoSurtidor` que importan: `Espera`, `Listo`, `Autorizado` (programado, esperando que levanten la manguera), `Surtiendo`, `Reporte`. `dinero` y `volumen` son tiempo real solo en equipos que lo soportan; si no, vienen en 0. Hoy `gradoPreset` siempre sale en 0 (el API no lee el campo que manda NSX).

### `POST api/Preset/CancelarPreset`  *(nuevo)*
```json
{ "identificador": "123456789012", "documento": "1234567890", "idPosicion": 5 }
```
Solo cancela un preset del turno de ese vendedor y no si la posición ya está surtiendo (NSX responde el motivo; llega como error 400 en `message`).

### `GET api/Preset/EstadoPreset?idPreset={id}`
Estado de un preset concreto (ya existía).

## 4. Fin de venta
### `GET api/Venta/preset/{idPreset}`  ·  `GET api/Venta/ultima?dispensador={n}&cara={n}`
Devuelven la venta (`idVenta`, `dinero`, `volumen`, `precioVenta`, `idPosicion`, …). `ultima` es la última venta de esa cara, **sea de quien sea**; solo se puede anclar forma de pago a una venta del turno del vendedor.

La venta ahora trae también `formasPago`: las formas de pago registradas de esa venta, cada una con `{ idFormaPago, nombre, valor, identificador }`. Lista vacía = la venta es efectivo (lo que no esté en la lista sigue siendo efectivo). Sirve para la pantalla "Formas de pago de la venta".

### `POST api/Venta/AnclarFormaPago`  *(nuevo)*
```json
{ "documento": "1234567890", "idVenta": 628359,
  "formasPago": [ { "idFormaPago": 23, "valor": 20000, "identificador": "ref-123" },
                  { "idFormaPago": 24, "valor": 10000 } ] }
```
- Por defecto una venta sin formas de pago es efectivo. Lo no anclado sigue siendo efectivo.
- Se puede llamar varias veces sobre la misma venta; el total anclado no puede superar el valor de la venta.
- Reglas: vendedor activo, venta de un turno **abierto** suyo, formas solo de `formasPagoVendedor` (no `QRVueltos`).
- `data`: `{ idVenta, valorVenta, anclado, efectivo }`.

## 5. Factura electrónica e impresión
### `GET api/Facturacion/ConsultarCliente?documento={doc}`  ·  `POST api/Facturacion/FacturarVenta`
```json
{ "idVenta": 628359, "documento": "900123456", "razonSocial": "...", "email": "..." }
```
`tipoDocumento` (entero) y `razonSocial`/`email` son opcionales. Ya existen y son los mismos que usa el flujo del cliente.

### `GET api/Impresion/ImprimirVenta?idVenta={id}`
Reimprime el recibo (ya existía).

## 6. Cómo lo ve la app (según `D:\Autoservicions2\gnesys_as`, la copia más reciente)
La app no usa las rutas `api/...` de arriba: llama a la Orange Pi con rutas `nsx-autoservice-api/V1/...` y recibe un sobre distinto:
```json
{ "isError": false, "message": "", "content": { "success": true, "message": "", "data": { } } }
```
Lo que ya existe en la Orange Pi y se reutiliza (equivalencia con el API):
| Ruta de la Orange Pi (la app ya la usa) | Endpoint del API |
|---|---|
| `nsx/shift/validate-seller` | `Turno/ValidarVendedor` |
| `nsx/status-position/{posicion}` | `Preset/ObtenerEstado` |
| `nsx/last-sale/{dispensador}/{cara}` | `Venta/ultima` |
| `nsx/print-sale` | `Impresion/ImprimirVenta` |
| `sale/bill`, `client/validation-dian` | `Facturacion/FacturarVenta`, `ConsultarCliente` |
| `mapping` | `Mapeo/ObtenerMapeo` (ahora con `hibrido` y `formasPagoVendedor`) |

Rutas nuevas que habría que publicar en la Orange Pi (los nombres son una sugerencia, los define quien las publica): abrir turno (`AbrirTurno`), preset de vendedor (`PresetVendedor`), cancelar preset (`CancelarPreset`), anclar forma de pago (`AnclarFormaPago`) y cerrar turno (`CerrarTurno`).

Dos datos de la app que importan: la pantalla de surtiendo consulta `status-position` cada 2 segundos, y el Inicio consulta ese mismo estado antes de dejar que un cliente empiece (solo continúa en `Espera` o `Listo`); el modo vendedor debe respetar la misma comprobación. La Orange Pi hoy devuelve de `status-position` un `gradoPreset` que el API manda siempre en 0.

## 7. Pendiente de definir
- **Para saber si puede anclar a la "última venta"**: convendría que `Venta` traiga también el `idTurno` o el documento del vendedor, para que la app sepa de antemano si la venta es de su turno. Hoy el API responde error 400 si no lo es.
- **Crédito** (la opción que ven los vendedores en la HMI) son dos comandos de NSX2: `C1` (leer el identificador del cliente: el cliente acerca el tag al surtidor, la caja pregunta y recibe `C1|PENDIENTE` hasta que lo lee, luego `C1|1|serial`) y `C2` (autorizar al cliente a cuenta con ese serial, placa, km y clave). Ninguno está portado a NSX Prime, y `C1` además necesita piezas de `PosCDG` que Prime no tiene (trama de identificador leído, envío de comando POS y serial recibido). El API de autoservicio tampoco tiene endpoints para ellos. En los bocetos aparece como propuesta.
- Para que la app sepa si puede anclar a la "última venta" (que puede ser de otro), conviene que `Venta` devuelva el turno o el documento del vendedor. Hoy el API responde error 400 "La venta no corresponde a un turno de este vendedor".
- Equipos con dos display por cara: el estado de cada display/posición se consulta con `ObtenerEstado` por posición; la app no debe quedarse fija en una sola pantalla de "Surtiendo".
- Tiempo de cierre automático de la sesión del vendedor por inactividad: definirlo en la app.
