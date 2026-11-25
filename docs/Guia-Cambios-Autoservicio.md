# Autoservicio en NSX Prime — cambios del API y nuevos métodos

Guía para quien mantiene la Orange Pi y la app. Resume lo que cambió en el API `NSXAutorserviceAPI` desde el 2026-10-15, con ejemplos de cada llamada. Las pruebas se hicieron contra el API local en el puerto 8091 y la base `EstacionNSX`.

## 1. Resumen

| Tema | Qué hay | Dónde |
|---|---|---|
| Vendedor de paso (modo híbrido) | Login, turno, preset, cancelar, anclar forma de pago | `Turno/*`, `Preset/PresetVendedor`, `Preset/CancelarPreset`, `Venta/AnclarFormaPago` |
| Cliente con identificador (crédito / prepago local) | Leer el identificador y autorizar al cliente | `Cliente/LeerIdentificador`, `Cliente/AutorizarCliente` (nuevos) |
| Tipos de identificador del autoservicio | Lista por dispositivo en el mapeo | `Mapeo/ObtenerMapeo` → `identificadores` |
| Fidelidad | Consultar cliente y acumular la venta (LifeMiles y Commodo) | `Fidelidad/ValidarCliente`, `Fidelidad/Acumular`; mapeo → `fidelidad` |
| Venta | Formas de pago, fidelización, cuenta del cliente, vuelto | `Venta/preset/{id}`, `Venta/ultima` |

## 2. Convenciones

- Todas las respuestas del API tienen el mismo sobre:
  ```json
  { "success": true, "message": "texto", "data": { }, "errors": null }
  ```
  En error: `success: false` y `message` con el motivo. Los errores de negocio de NSX llegan en `message` tal cual.
- `identificador` es la MAC del dispositivo (12 caracteres). El `documento` del vendedor es **numérico**.
- Los valores de dinero van como número sin separadores (`50000`).

## 3. Mapeo (`GET api/Mapeo/ObtenerMapeo?identificador={mac}`)

Campos nuevos o que cambian:

- `dispensadores[].hibrido` (bool): si es `true`, la app muestra el acceso de vendedor.
- `formasPagoVendedor[]`: formas de pago que ve el vendedor. Para el vendedor se usa `idFormaPago`.
- `fidelidad[]`: programas disponibles, cada uno `{ idFidelidad, nombre }`. Hoy: `{ 3, "Commodo" }`. Los ids son fijos:

  | id | Programa |
  |---|---|
  | 1 | PuntosColombia |
  | 2 | LifeMiles (se muestra "ViveTerpel") |
  | 3 | Commodo |
  | 4 | Local |
  | 5 | Leal |
- `identificadores[]`: tipos de identificador que ofrece **ese dispositivo**, cada uno `{ id, nombre }`:

  | id | Nombre | Qué se manda |
  |---|---|---|
  | 1 | iButton | `serial` leído con `LeerIdentificador` |
  | 2 | Teclado | código en `serial` y `clave` |
  | 3 | Placa | la placa en `serial` (no se lee) |

  La lista sale de `Autoservice.Dispositivo.IdentificadoresCliente` (banderas `iButton|Teclado|Placa`). La app debe mostrar solo los que vengan en la lista.

## 4. Vendedor de paso

Para dispositivos con `hibrido: true`. Sin contraseña salvo en el login.

- `POST api/Turno/ValidarVendedor` — `{ "documento", "password" }` → `{ idIslero, cedula, nombre, apellidos, activo }`. 401 si las credenciales son inválidas.
- `POST api/Turno/AbrirTurno` — `{ "identificador", "idPosicion", "documento", "password" }`. Si el vendedor ya tiene turno abierto, NSX lo reutiliza.
- `POST api/Turno/CerrarTurno` — mismo cuerpo. Cerrar sesión no cierra el turno.
- `POST api/Preset/PresetVendedor` — `{ "identificador", "documento", "idPosicion", "numeroManguera", "tipoProgramacion", "valor", "placa", "km" }`.
  - `tipoProgramacion`: 1 lleno, 2 dinero, 3 volumen. Con 1 el valor no se usa.
  - Usa el turno abierto del vendedor. Sin forma de pago, la venta es en efectivo. → `{ idPreset }`.
- `POST api/Preset/CancelarPreset` — `{ "identificador", "documento", "idPosicion" }`. Solo cancela un preset del turno de ese vendedor y no si ya está surtiendo.
- `POST api/Venta/AnclarFormaPago` — `{ "documento", "idVenta", "formasPago": [ { "idFormaPago", "valor", "identificador" } ] }`.
  - Sin formas de pago la venta es efectivo. El total anclado no puede superar el valor de la venta.
  - Reglas: vendedor activo, venta de un turno abierto suyo, formas solo de `formasPagoVendedor`. → `{ idVenta, valorVenta, anclado, efectivo }`.
- `GET api/Preset/ObtenerEstado?idPosicion={n}` — `estadoSurtidor`: `Espera`, `Listo`, `Autorizado`, `Surtiendo`, `Reporte`.

## 5. Cliente con identificador (crédito / prepago local)

Dos pasos. Equivalen a los comandos `C1` y `C2` de NSX.

### 5.1 `POST api/Cliente/LeerIdentificador`

```json
{ "identificador": "123456789012", "idPosicion": 5, "tipo": 1, "timeoutSegundos": 30 }
```

- `tipo`: 1 iButton, 2 Teclado. El 3 (placa) responde error: la placa no se lee, se envía en el paso 2.
- **La petición queda abierta**: el API pide la lectura al MUX y consulta cada 0,5 s hasta que el cliente pasa el identificador o se agota `timeoutSegundos` (30 por defecto, máximo 120).
- Respuesta: `data: { "serial": "..." }`. Si no lee a tiempo: error "No se leyó el identificador en N segundos".
- Errores: "Tipo de identificador no habilitado en este dispositivo".

### 5.2 `POST api/Cliente/AutorizarCliente`

```json
{ "identificador": "123456789012", "idPosicion": 5, "numeroManguera": 3,
  "tipoProgramacion": 2, "valor": 50000, "km": 12000,
  "serial": "00A4F91C", "clave": null, "tipoIdentificador": 1,
  "documento": "1234567890" }
```

- `tipoIdentificador`: 1 iButton, 2 Teclado, 3 Placa. Debe estar habilitado en el dispositivo.
  - **1:** `serial` es el que devolvió `LeerIdentificador`.
  - **2:** `serial` es el código del cliente y `clave` es obligatoria.
  - **3:** `serial` es la placa. El API busca el identificador activo del vehículo con esa placa. Si no hay: "No hay un identificador activo para esa placa". Si hay varios: "La placa tiene varios identificadores activos".
- `valor` es obligatorio salvo en `tipoProgramacion` 1 (lleno).
- `km` y `documento` (del vendedor) son opcionales. Con `documento` la venta va al turno abierto de ese vendedor; sin él, al turno abierto de la isla.
- Respuesta: `data: { "idPreset": 15234, "mensaje": "Vehiculo Autorizado Placa: ...\nCuenta: ...\nProducto: ..." }`. Con `idPreset` se consulta `Preset/EstadoPreset` y se cancela con `Preset/CancelarPreset`.
- Errores de NSX (llegan en `message`): identificador no registrado o inactivo, restricciones, saldo, turno, posición ocupada.

## 6. Fidelidad

Las dos llamadas funcionan **con el id de programa del mapeo**.

### 6.1 `POST api/Fidelidad/ValidarCliente` — consultar al cliente

```json
{ "identificador": "123456789012", "idTipoFidelidad": 3, "tipoDocumento": 13, "documento": "3001234567" }
```

- `tipoDocumento` es el **código DIAN**. Para LifeMiles: 13 cédula, 22 extranjería, 41 pasaporte, 10 celular. Para **Commodo siempre se usa el celular** y se ignora lo que llegue (debe ser mayor que 0).
- Respuesta (solo programa y nombre):
  ```json
  { "success": true, "message": "Cristian Zamudio",
    "data": { "idFidelidad": 3, "programa": "Commodo", "nombre": "Cristian Zamudio" } }
  ```
  `nombre` es el nombre del **cliente**.

### 6.2 `POST api/Fidelidad/Acumular` — acumular una venta

```json
{ "identificador": "123456789012", "idTipoFidelidad": 3, "idVenta": 628364,
  "tipoDocumento": 13, "documento": "3001234567", "nombreCliente": "Cristian Zamudio" }
```

- Acumula la venta **que se indique en `idVenta`** (no la última de la posición). La acumulación es inmediata.
- `nombreCliente` es opcional, pero conviene enviar el que devolvió `ValidarCliente`: Commodo solo responde "Transaccion Exitosa" y el API devuelve ese nombre.
- Respuesta:
  ```json
  { "success": true, "message": "Transaccion Exitosa",
    "data": { "idFidelidad": 3, "programa": "Commodo", "nombre": "Cristian Zamudio",
              "acumulado": null, "mensaje": "Transaccion Exitosa" } }
  ```
  `acumulado` trae las millas ganadas en la venta cuando el programa las reporta (LifeMiles); con Commodo va `null`.
- La llamada espera hasta ~12 s la respuesta del programa. Si no responde: `success: false` con "La acumulacion sigue en proceso, consulte en un momento". En ese caso la acumulación sigue y el resultado queda en la venta (ver 7).
- Si falla, `success: false` y `message` con el motivo.

## 7. La venta ahora trae más datos

`GET api/Venta/preset/{idPreset}` y `GET api/Venta/ultima?dispensador={n}&cara={n}`:

```json
{ "idVenta": 628364, "tipoTransaccion": 2, "vuelto": 0, "vueltoRegistrado": false,
  "fidelizacion": { "acumulo": true, "fecha": "...", "idFidelidad": 3, "programa": "Commodo",
                    "documento": "...", "nombre": "...", "acumulado": null },
  "cliente": { "cuenta": "NOMBRE CUENTA", "empresa": "RAZON SOCIAL", "placa": "ABC123", "kilometraje": 12000 },
  "formasPago": [ { "idFormaPago": 1, "nombre": "Visa", "valor": 100, "identificador": "..." } ] }
```

- `fidelizacion`: `acumulo` es `true` si la venta ya tiene una acumulación exitosa. `idFidelidad` y `programa` dicen de qué programa (2 sale como "ViveTerpel"); van vacíos si la acumulación no registró el programa.
- `cliente`: cuenta, empresa, placa y kilometraje de la venta. **Solo aparece en ventas con cliente** (prepago, crédito...); en efectivo (`tipoTransaccion` 1) va `null`.
- `vuelto` y `vueltoRegistrado`: en `tipoTransaccion` 1 (efectivo) no aplican y van en `0` / `false`.
- `formasPago`: lista vacía = la venta es efectivo.

## 8. Qué debe hacer la Orange Pi

1. Reenviar el mapeo completo (los campos `fidelidad` e `identificadores` son nuevos).
2. Publicar rutas nuevas para: abrir y cerrar turno, `PresetVendedor`, `CancelarPreset`, `AnclarFormaPago`, `LeerIdentificador`, `AutorizarCliente`. Los nombres son sugerencia.
3. En `LeerIdentificador` mantener la petición abierta o aumentar el tiempo de espera: puede tardar hasta `timeoutSegundos`.
4. Enviar `nombreCliente` en `Acumular`, y `idVenta` con la venta a acumular.
5. Mostrar en la app solo los identificadores y los programas de fidelidad que vengan en el mapeo.
