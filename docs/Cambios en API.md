# Cambios en el API de autoservicio (NSXAutorserviceAPI)

Ruta: `D:\Autoservice\Repositorio\Autoservice\NSXAutorserviceAPI`. Cada cambio se consultó antes con ejemplos. Compila con `dotnet build`; sin probar contra un MUX.

## A. Mapeo con modo híbrido y formas de pago del vendedor (2026-10-15)
- **MODIFICADO** `NSXAutoservice.Models\DispensadorModel.cs`: campo `Hibrido` (bool).
- **MODIFICADO** `NSXAutoservice.Models\MapeoModel.cs`: lista `FormasPagoVendedor`, aparte de `FormasPago` (que sigue siendo la del autoservicio).
- **MODIFICADO** `NSXAutoservice.Core\Consultas.cs`:
  - `ObtenerDispensadoresByIdentificador` lee `Autoservice.Dispositivo.ModoHibrido`; si la columna no existe (base NSX2 sin el script 02) devuelve `false`.
  - **NUEVO** `ObtenerFormasDePagoVendedor`: `FormaPago.FormaPago` con `Activo = 1`; el id es el del sistema.
  - `ObtenerMapeo(identificador)` llena `FormasPagoVendedor`.
- `QRVueltos` se excluye de la lista del vendedor (por ahora): requiere reservar el vuelto, que `AnclarFormaPago` no hace. Como el anclaje solo acepta formas de esa lista, también queda rechazada ahí.

## B. Preset de vendedor de paso (endpoint aparte)
`POST api/Preset/PresetVendedor`
```json
{ "identificador": "123456789012", "documento": "1234567890", "idPosicion": 5, "numeroManguera": 1,
  "tipoProgramacion": 2, "valor": 50000, "placa": "ABC123", "km": 12000 }
```
- Solo el documento (sin contraseña). El API busca al vendedor, exige que esté activo y tenga un turno abierto (por islero, no por MAC) y manda `P1` con ese turno en el campo 11. Sin formas de pago: la venta queda en efectivo.
- **NUEVO** `Models\Request\PresetVendedorRequest.cs`.
- **MODIFICADO** `Services\Interfaces\IAutoservicioService.cs`: `CrearPresetVendedor`.
- **MODIFICADO** `Services\Implementations\NSXAutoservicioService.cs`: `CrearPresetVendedor`; la parte común de `ProcesarPreset` (enviar el comando y esperar la programación) se extrajo a `EnviarPresetYEsperar`, que usan `PAS` y `P1`. Sin cambio de comportamiento en `PAS`.
- **MODIFICADO** `Services\Implementations\GNESYSAutoservicioService.cs`: `CrearPresetVendedor` responde que no está disponible.
- **MODIFICADO** `Controllers\PresetController.cs`: endpoint `PresetVendedor`.
- **NUEVO** `Consultas.ObtenerIdTurnoAbiertoByIslero`.

## B2. Cancelar el preset del vendedor
`POST api/Preset/CancelarPreset`
```json
{ "identificador": "123456789012", "documento": "1234567890", "idPosicion": 5 }
```
- El API resuelve el turno abierto del vendedor y manda `S` con ese turno en el campo 3 (`mac|pos|S|turno`). Prime rechaza si el preset de la posición no es de ese turno (`El preset de esta posicion no pertenece a su turno`) o si la posición ya está surtiendo.
- Éxito: `S|1|OK`; cualquier otra respuesta se devuelve como error 400 con el mensaje de NSX.
- **NUEVO** `Models\Request\CancelarPresetVendedorRequest.cs`. **MODIFICADO** `IAutoservicioService` (`CancelarPresetVendedor`), `NSXAutoservicioService`, `GNESYSAutoservicioService` (no disponible) y `PresetController`.
- No se tocó `CancelarPreset(PresetRequest)` (el interno, con el booleano que parece invertido).

## B3. La venta trae sus formas de pago
Sin endpoint nuevo: `GET api/Venta/preset/{idPreset}` y `GET api/Venta/ultima` devuelven ahora `formasPago`:
```json
{ "idVenta": 628360, "dinero": 45680, "...": "...",
  "formasPago": [ { "idFormaPago": 1, "nombre": "Visa", "valor": 45680, "identificador": "" } ] }
```
Lista vacía = efectivo. Salen de `FormaPago.DetalleFormaPago` (tipo de compra combustible, activas) con el nombre de `FormaPago.FormaPago`.
- **NUEVO** `Models\FormaPagoRegistradaModel.cs`; **MODIFICADO** `Models\VentaModel.cs` (`FormasPago`) y `Core\Consultas.cs` (`EjecutarConsultaVenta` completa la venta; `ObtenerFormasPagoVenta`).
- Solo en el modo NSX (en GNESYS la lista queda vacía: sus tablas de venta son otras).
- Probado en solo lectura contra la base: la venta 628360 devuelve su fila (Visa) y la 628359 ninguna (efectivo). No se ha ejecutado la llamada completa del API.
- Nombre `FormaPagoRegistradaModel` porque ya existía un `VentaFormaPagoModel` de reportes.

## C. Anclar formas de pago después de la venta
`POST api/Venta/AnclarFormaPago`
```json
{ "documento": "1234567890", "idVenta": 628359,
  "formasPago": [ { "idFormaPago": 23, "valor": 20000, "identificador": "ref-123" },
                  { "idFormaPago": 24, "valor": 10000 } ] }
```
Sin filas de forma de pago la venta es efectivo, así que anclar solo agrega filas a `FormaPago.DetalleFormaPago` (tipo de compra 1, ligadas a la venta y al turno de la venta). Se puede llamar varias veces sobre la misma venta.
- Reglas: vendedor activo (solo documento); la venta debe ser de un turno **abierto** de ese vendedor; cada forma debe estar en `FormasPagoVendedor` del mapeo; el total anclado (lo previo más lo nuevo) no puede superar `Venta.ValorTotal`. Lo no anclado sigue siendo efectivo.
- Respuesta: `{ idVenta, valorVenta, anclado, efectivo }`.
- Todo en una transacción serializable (se bloquea la suma previa), para que dos anclajes simultáneos no se pasen del valor.
- **NUEVO** `Models\Request\AnclarFormaPagoRequest.cs`; **MODIFICADO** `Consultas.cs` (`AnclarFormasPago`) y `Controllers\VentaController.cs` (endpoint).
- No replica el tratamiento especial del preset de autoservicio (reserva de vuelto con QR, detalle de transacción de tarjeta): el identificador se guarda tal cual.

## D. Métodos de prueba para `C1` y `C2` (2026-10-16)
Nuevo `Controllers\ClienteController.cs` (`api/Cliente`). Compila; sin probar contra NSX.

`POST api/Cliente/LeerIdentificador` (comando `C1`)
```json
{ "identificador": "123456789012", "idPosicion": 5, "tipo": 1, "timeoutSegundos": 30 }
```
`tipo` es la posición en la configuración `IDCliente` (1 Ibutton, 2 Tag, 3 Teclado, 4 Banda magnética, 5 Código de barras, 6 QR); NSX rechaza un tipo inactivo. **La petición queda abierta**: el API inicia la lectura en el MUX y consulta cada 0,5 s hasta que lo lee. Respuesta: `{ "serial": "00A4F91C" }`; si no lo lee en `timeoutSegundos` (30 por defecto, máximo 120) responde error 400 "No se leyó el identificador en N segundos".

`POST api/Cliente/AutorizarCliente` (comando `C2`)
```json
{ "identificador": "123456789012", "idPosicion": 5, "numeroManguera": 1, "tipoProgramacion": 2, "valor": 50000,
  "serial": "00A4F91C", "clave": "", "tipoIdentificador": 1 }
```
Opcionales: `placa` (si no viene se usa la del vehículo del identificador), `km` y `documento` (del vendedor: la venta va a su turno abierto; sin él va al turno abierto de la isla). No se pide conductor (siempre 0). `tipoIdentificador` es la posición en `IDCliente` (1 a 7); el teclado (3) lleva `clave`. Respuesta: `{ "idPreset": 15234, "mensaje": "Vehiculo Autorizado Placa: ABC123\nCuenta: …\nProducto: …" }`; con `idPreset` se consulta `Preset/EstadoPreset` y se cancela con `Preset/CancelarPreset`. NSX responde `E|0|motivo` si no valida (identificador inexistente, restricciones, saldo, turno, posición ocupada) y el API lo devuelve como error 400.

- **NUEVO** `Models\Request\LeerIdentificadorRequest.cs`, `Models\Request\AutorizarClienteRequest.cs`, `Controllers\ClienteController.cs`.
- **MODIFICADO** `IAutoservicioService` (`LeerIdentificador`, `AutorizarCliente`), `NSXAutoservicioService` (implementación) y `GNESYSAutoservicioService` (no disponible).
- Pendiente: que el mapeo traiga los tipos de identificador activos (`IDCliente`), como `hibrido`.
