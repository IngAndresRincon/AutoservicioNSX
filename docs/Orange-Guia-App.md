# Autoservicio NSX — Orange Pi: cómo quedó y cómo usarlo desde la app

Guía para quien desarrolla la app. Resume lo que se agregó a la Orange (`service` y `consola`) y al API entre el 2026-10-21 y 2026-10-22, con las rutas, los avisos y las reglas. Todo se probó de punta a punta en un entorno local (Postgres + `service` + `consola` + API 8091 + NSX Prime) con surtidor real en las posiciones 5 y 6.

## 1. Cómo encaja todo

```
App/pantalla ──HTTP──▶ service (Express, :5001) ──HTTP──▶ API NSXAutorserviceAPI ──TCP──▶ NSX ──▶ surtidor
      ▲                      │  ▲
      └──── Socket.IO ───────┘  └── Postgres (BD local de la Orange) ◀── consola (procesos en segundo plano)
```

- **`service`**: lo que llama la app. Base: `/nsx-autoservice-api/V1`.
- **`consola`**: sincroniza el mapeo, envía las autorizaciones del autoservicio, sigue cada preset hasta que hay venta y abre/cierra el turno del autoservicio.
- **Postgres**: guarda el mapeo, los presets y las ventas, y avisa cada cambio de estado a `service` con `pg_notify`.
- Autenticación de la app: encabezado `x-api-key` en todo. Las rutas del vendedor piden además `Authorization: Bearer <token>`.

## 2. Tres formas de despachar

| Flujo | Quién | Cómo se paga | Dónde queda registrado |
|---|---|---|---|
| **Autoservicio** (ya existía) | Cliente solo | Paga antes (QR, datáfono, Nequi) | `programacion` → `autorizacion` |
| **Vendedor de paso** (nuevo) | Vendedor en dispensador híbrido | Se paga después; se anclan las formas de pago | `preset_vendedor` |
| **Cliente con identificador** (nuevo) | iButton, teclado o placa; solo o con vendedor | Cargo a la cuenta del cliente en NSX | `preset_cliente` |

## 3. Mapeo: campos nuevos

`GET /mapping?screenid={n}` ahora trae, además de lo anterior:

- `productHoses[].hybrid` (bool): si el dispensador es híbrido. Con `true` la app muestra el acceso de vendedor.
- `identifiers[]`: tipos de identificador habilitados en este equipo, `{ identifierid, name }`. Hoy 1 iButton, 2 Teclado, 3 Placa. **La app debe mostrar solo los que vengan.**
- `sellerPaymentMethods[]`: formas de pago que puede anclar el vendedor, `{ nsxpaymentid, name }`.
- `fidelity[]`: programas de fidelidad. `nsx_fidelity_id` es el que se manda a las rutas de fidelidad (3 = Commodo).

## 4. Vendedor de paso (`/seller`)

Solo para posiciones de dispensadores híbridos (si no: 403). `positionId` es el id local de la posición (`positionid` del mapeo).

| Ruta | Cuerpo | Qué hace |
|---|---|---|
| `POST /seller/login` | `document`, `password` | Valida al vendedor y entrega el token. Solo requiere `x-api-key`. |
| `POST /seller/shift/open` | `positionId`, `password` | Abre el turno del vendedor en NSX. |
| `POST /seller/shift/close` | `positionId`, `password` | Cierra el turno. Cerrar sesión no lo cierra. |
| `POST /seller/preset` | `positionId`, `hoseNumber`, `programmingType`, `value`, `plate`, `km` | Programa el preset. |
| `POST /seller/preset/cancel` | `positionId` | Cancela el preset activo del vendedor en esa posición (no si ya está surtiendo). |
| `GET /seller/preset/{id}` | — | Estado del preset (para consultar en vez de esperar el aviso). |
| `POST /seller/sale/payments` | `saleId`, `paymentMethods[]` | Ancla las formas de pago a la venta. |

- `programmingType`: 1 lleno (no lleva `value`), 2 dinero, 3 volumen.
- `paymentMethods[]`: `{ paymentMethodId, amount, reference }`. Sin formas de pago la venta es efectivo. Solo se aceptan las de `sellerPaymentMethods`.

**Sesión:** el token dura **8 horas** (`SELLER_TOKEN_HOURS`). Al vencer, las rutas responden 401 "La sesión del vendedor expiró": la app debe volver a pedir el login. El turno en NSX no se cierra. La clave solo se vuelve a pedir al abrir y cerrar turno. El documento sale siempre del token, no del cuerpo.

**Login:** 5 intentos fallidos en 5 minutos para el mismo documento bloquean ese documento con 429 (se levanta solo; en memoria).

Ejemplo — crear preset:
```json
POST /seller/preset   Authorization: Bearer <token>
{ "positionId": 1, "hoseNumber": 3, "programmingType": 2, "value": 2000 }
→ 201 { "isError": false, "message": "Preset del vendedor registrado",
        "content": { "id": 3, "sincronizado": 2, "id_presetnsx": 631516, "id_venta": null,
                     "id_turno_vendedor": 1, ... } }
```

Ejemplo — anclar pagos:
```json
POST /seller/sale/payments   { "saleId": 628376, "paymentMethods": [ { "paymentMethodId": 1, "amount": 2000, "reference": "VISA-123" } ] }
→ { "content": { "idVenta": 628376, "valorVenta": 2000, "anclado": 2000, "efectivo": 0 } }
```

## 5. Cliente con identificador (`/client`)

Dos pasos, como los comandos `C1` y `C2` de NSX. Con **token de vendedor** la venta queda en el turno del vendedor; **sin token** (cliente solo), en el turno del autoservicio.

**Paso 1 — leer el identificador** (iButton o teclado):
```json
POST /client/identifier/read   { "positionId": 1, "type": 1, "timeoutSeconds": 30 }
→ { "content": { "serial": "B60000010CDE8F01" } }
```
- **La petición queda abierta** hasta que el cliente pasa el identificador o vence `timeoutSeconds` (30 por defecto, máximo 120). La app debe esperar la respuesta. Si vence: "No se leyó el identificador en N segundos".
- Una sola lectura a la vez por posición (409 si ya hay una).
- La placa (3) no se lee; se manda en el paso 2.

**Paso 2 — autorizar:**
```json
POST /client/authorize   [Authorization: Bearer <token>  — opcional]
{ "positionId": 1, "hoseNumber": 1, "programmingType": 2, "value": 2000, "km": 12000,
  "identifierType": 2, "serial": "INS002", "key": "<clave>" }
→ 201 { "content": { "id": 4, "sincronizado": 2, "id_presetnsx": 631520,
        "mensaje": "Vehiculo Autorizado Placa: INS002\nCuenta: INSEPET\nProducto: GASOLINA EXTRA", ... } }
```
| `identifierType` | `serial` es | `key` |
|---|---|---|
| 1 iButton | el serial leído en el paso 1 | no |
| 2 Teclado | el código del cliente | **obligatoria** (nunca se guarda ni se registra en logs) |
| 3 Placa | la placa | no (NSX busca el identificador activo de la placa) |

- `km` es opcional. Con token de vendedor, el `documento` se toma del token.
- `GET /client/preset/{id}` consulta el estado (con token si el preset es de un vendedor).
- Los rechazos de NSX llegan con su mensaje (por ejemplo "no está autorizado para este producto, el vehículo tiene autorizado → EXTRA", identificador inactivo, saldo).

## 6. Fidelidad (rutas existentes, ahora con más datos)

`POST /nsx/fidelity/validate-customer` y `POST /nsx/fidelity` (cuerpo: `fidelityTypeId` = id de NSX, `saleId`, `documentType`, `documentNumber`, `customerName` opcional).

- Si el programa no está en el mapeo: 400.
- `validate-customer` devuelve `data: { idFidelidad, programa, nombre, saldo }` (`saldo` es `null` si el programa no lo informa).
- `fidelity` (acumular) acepta `customerName` y devuelve `data: { ..., acumulado, saldo, mensaje }`. En Commodo, `acumulado` es el saldo de después menos el de antes y `saldo` es el actual (ej. 5,08 → +5,08 → 10,16). La venta acumulada es la indicada en `saleId`, no la última de la posición.
- Commodo siempre usa el celular como documento.

## 7. Estados y avisos por Socket.IO

Conexión: `serial` de la pantalla (en `auth`) y la key de socket (`x-api-key`). El servidor reenvía los eventos a todas las pantallas; **cada una debe filtrar por su `serial`**.

Canales nuevos (el contenido llega en `event.payload`):

| Canal | Cuándo |
|---|---|
| `notify_event_preset_vendedor` | cambia el estado de un preset del vendedor |
| `notify_event_preset_cliente` | cambia el estado de un preset de cliente identificado |

Los canales anteriores (`notify_event_authorization`, `notify_event_transaction_payment`) siguen igual.

Campos del contenido: `serial`, `positionid`, `hosenumber`, `programmingtypeid`, `value`, `id_presetnsx`, `saleid`, `sync`, `message`; el de vendedor trae `sellerpresetid` y `document`; el de cliente trae `clientpresetid`, `identifiertypeid` y `sellerdocument`.

Valores de `sync` (tabla `estado`):

| `sync` | Significado | Qué muestra la app |
|---|---|---|
| 2 | Confirmado: NSX creó el preset | "Autorizado, levante la manguera" |
| 8 | Despachando | "Surtiendo" |
| 4 | Reportado: hay venta (`saleid`) | "Venta terminada" |
| 3 | Rechazado (`message` trae el motivo) | mostrar el error |
| 5 | Anulado (el vendedor canceló) | volver al inicio |
| 6 | Venta en cero | "Sin venta" |

Los eventos de una venta llegan en orden `2 → 8 → 4`. La app puede esperar el evento o consultar el estado con `GET .../preset/{id}`; las dos formas dan lo mismo.

## 8. Reglas que debe conocer la app

- **Una posición, un despacho a la vez.** Si hay autoservicio, vendedor o cliente identificado activos en una posición, cualquier otro intento responde **409**. Aplica al crear la programación del autoservicio (antes de que el cliente pague), al programar como vendedor y al autorizar un cliente. `consola` además espera a enviar la autorización del autoservicio hasta que la posición esté libre, sin darla por fallida.
- **Los presets del vendedor y del cliente no vencen por tiempo:** se cierran según el estado del preset en NSX. Solo una reserva sin completar (más de 2 minutos) se libera sola.
- **Turno de cada venta:** autoservicio y cliente solo → el turno del autoservicio. Vendedor, o cliente atendido por un vendedor → el turno del vendedor. La Orange guarda el turno del vendedor al abrirlo con `service`.

## 9. Códigos HTTP del vendedor y del cliente

| Código | Cuándo |
|---|---|
| 400 | datos faltantes o inválidos, tipo de identificador no habilitado, forma de pago no habilitada, rechazo de validación de NSX |
| 401 | falta el token, token vencido, credenciales inválidas |
| 403 | token inválido o de otro tipo, posición de dispensador no híbrido, vendedor inactivo, preset de otro vendedor |
| 404 | posición, preset o venta inexistente |
| 409 | posición ocupada, lectura de identificador en curso |
| 429 | demasiados intentos de login |
| 502 | NSX o el API no respondieron |

El `message` es el motivo real que devuelve el API/NSX. Las rutas anteriores del `service` aún convierten cualquier error del API en 502 genérico (pendiente).

## 10. Cambios en la base de datos de la Orange

Scripts idempotentes en `consola/database/migrations/` (ejecutar en orden sobre `Autoservicio_nsx2`):

| Script | Qué agrega |
|---|---|
| `001_mapeo_hibrido_identificadores.sql` | `dispensador.hibrido`; tablas `identificador_cliente` y `forma_pago_vendedor` |
| `002_preset_vendedor.sql` | `preset_vendedor`, `preset_vendedor_pago`, trigger y canal `notify_event_preset_vendedor` |
| `003_turno_vendedor.sql` | `turno_vendedor`; `preset_vendedor.id_turno_vendedor`; `venta.id_turno_vendedor` |
| `004_preset_cliente.sql` | `preset_cliente`, trigger y canal `notify_event_preset_cliente` |

El mapeo se llena solo cuando `consola` sincroniza (`modulo.sincronizar = true`). **Atención:** esa sincronización vacía y vuelve a llenar varias tablas, entre ellas `turno`, `forma_pago` y `pantalla`. Por eso, al sincronizar, `consola` cierra y reabre el turno del autoservicio.

## 11. Cambios en el API (puerto 8091)

- `Fidelidad/ValidarCliente`: devuelve `saldo`.
- `Fidelidad/Acumular`: devuelve `saldo` y, en Commodo, `acumulado` calculado.
- El resto de rutas (`Turno/*`, `Preset/PresetVendedor`, `Preset/CancelarPreset`, `Venta/AnclarFormaPago`, `Cliente/*`) ya existían; `service` ahora las usa.

## 12. Configuración (variables de entorno de `service`)

`SELLER_TOKEN_HOURS` (8), `SELLER_LOGIN_MAX_ATTEMPTS` (5), `SELLER_LOGIN_WINDOW_MS` (300000). De `consola`: `PRESET_SELLER_INTERVAL_MS` (3000). `JWT_SECRET` firma el token del vendedor.

## 13. Qué se probó

| Prueba | Resultado |
|---|---|
| Mapeo con híbrido, identificadores y formas del vendedor | guardado y servido |
| Fidelidad Commodo: consulta, acumulación, saldo | ok (5,08 → 10,16) |
| Vendedor: login, turno, preset, aviso, venta, anclar pagos, cancelar | ok |
| Reglas anti-cruce autoservicio / vendedor / cliente | 409 en ambos sentidos |
| Bloqueo de login a los 5 intentos | ok (429) |
| Cliente iButton `B60000010CDE8F01`, solo | venta 628379, turno autoservicio |
| Cliente placa `INS001`, con vendedor | venta 628380, turno del vendedor |
| Cliente teclado `INS002` + clave, solo | venta 628381, turno autoservicio |
| Avisos por Socket.IO en los dos canales nuevos | `2 → 8 → 4` |

## 14. Pendientes conocidos

- **NSX2:** fidelidad completa (acumular la venta indicada, LifeMiles venta anterior, saldo con otro formato de texto). Con NSX2 el saldo y lo acumulado en Commodo salen `null`.
- Sincronizar los precios de NSX con la Orange cuando cambien (hoy solo al sincronizar el módulo).
- Códigos HTTP y mensajes de las rutas anteriores del `service`.
- Ids de formas de pago fijos en el código (3 = QR Vueltos, 2 = Nequi).
- Las autorizaciones del autoservicio en estado 8 quedan huérfanas si `consola` se reinicia.
- Un intento de teclado con un producto no autorizado se quedó esperando 20 s una vez (no se reprodujo).
- Colección de Postman: por actualizar.
