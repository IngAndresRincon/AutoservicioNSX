# Cambios hechos en NSX Prime (inventario para revisar)

Ruta base: `NSX-Prime\Software\Codigo NSX Prime\`. Todos compilan (`Estacion.Poll`, `Estacion.Core`, `Estacion.Impresion`, `Estacion.ImpresionPosicion`); ninguno está probado con equipo real.

**Actualización (turnos y venta en el autoservicio híbrido):** los cambios de la sección 4 sobre `T1`, `T2`, `P1` y el cierre, y el archivo `MixedAutoserviceService.cs`, se hicieron **con la herramienta de edición directa** (se ven como diff en la app). El archivo nuevo se normalizó a CRLF con BOM como el resto del proyecto.

**Nota sobre el método:** los demás cambios los apliqué con scripts de Python (por el BOM y los saltos CRLF de los archivos), y por eso no los viste como diff en la app. A partir de ahora se editan las clases directamente con la herramienta de edición. Las marcas **NUEVO** son código agregado; **MODIFICADO** son líneas que ya existían y cambié (con el antes y el después).

## 1. `Estacion.Protocolos\IPosicion.cs`
- **NUEVO** (línea 124): `int GetGradoPreset(int idPosicion);`

## 2. `Estacion.Protocolos\ProtocoloCDG\PosEmr3.cs`
- **NUEVO** (línea 1094): `GetGradoPreset` devuelve `0`.

## 3. `Estacion.Protocolos\ProtocoloCDG\PosCDG.cs`
**NUEVO**
- Campos (líneas 47–54): `_gradoPreset`, `_realTimeSoportado` (bool?), `_pollsSinRealTime`, `_firmwareMux`, `_intentosVersionMux`, `_waitRealTime = 60`.
- Métodos (líneas 5880–5930): `GetGradoPreset`, `GetFirmwareMux`, `DetectarFirmware` (pregunta la versión del MUX una vez, en `Espera`, hasta 3 intentos), `ActualizarTiempoReal`.
- Línea 1908: `case 0xA1` en el cálculo de largo de trama (en estado Surtiendo espera 26 bytes si el equipo manda tiempo real).

**Corregido en la revisión:** mi script había dejado dos bytes NUL reales dentro de `'\0'` en `DetectarFirmware` (líneas 5893 y 5904). Compilaba, pero un NUL en el fuente hace que los editores y las herramientas de diferencias traten el archivo como binario. Ya están como `'\0'`; se verificó que ningún archivo editado tenga caracteres de control raros, ni LF sueltos, y que el BOM siga.

**MODIFICADO**
| Línea | Antes | Después |
|---|---|---|
| 603 (`Programar`) | `_posComunicacion.EscribirBuffer(comando);` | antes de esa línea se agrega `_gradoPreset = grado + 1;` |
| 827 (`VersionMux`) | `if (i == 0) { return respuestaMux; }` | `return respuestaMux;` (sale en el primer byte que no llega) |
| 836–861 (`VersionMux`) | reconocía `S` y `D` | además guarda `_firmwareMux` y reconoce `G` Gilbarco, `Z` Zcheng, `W` Wayne, `L` MUXNSX2LEOS |
| 1785–1790 (lectura de estado) | `if (!_posComunicacion.LeerByte(_wait))` | `bool sondeoRealTime = ...;` y `LeerByte(sondeoRealTime ? _waitRealTime : _wait)`; si el sondeo no recibe nada: `_realTimeSoportado = false; break;` |
| 1968 | `if (respuesta[0] != 0xBC) { return null; }` | `{ _realTimeSoportado = null; return null; }` |
| 1981 (`case 0xA1` de estado) | solo asignaba el estado | además llama `ActualizarTiempoReal(respuesta);` |
| 2250 (fin de la lectura de estado) | — | se agrega `DetectarFirmware();` antes de devolver el estado |

## 4. `Estacion.Pool\LazoComunicacion.cs` (solo código agregado)
**NUEVO** en `ComandoPOS`:
- `case "E"` (línea 4247): estado, con tiempo real si el equipo lo manda.
- `case "T1"` (4287) y `case "T2"` (4295): abrir y cerrar turno.
- `case "PAS"` (4303): preset de autoservicio.
- `case "S"` (4309): stop de un preset.
- `case "I1"` y `case "I2"` (4315 y 4321): copia de recibo (la última de la posición, y por id de venta).

**NUEVO** métodos privados:
- `SolicitarCopiaRecibo` (`I1`), `SolicitarCopiaReciboIdVenta` (`I2`) e `ImprimirEfectivo(idPosicion, idVenta)`, portados de NSX2 **sin la parte de firma** (Prime no la tiene). `I2` solo atiende los tipos Efectivo (1) y Autoservicio (20); otros tipos responden `E|0|Copia de recibo no disponible para el tipo de transaccion N` (NSX2 también atiende crédito, satélite, master y texaco). `ImprimirEfectivo` reimprime la copia guardada y, si no hay, genera el recibo de nuevo (`ObtenerVentaEfectivo`), y lo encola en `ImpresionPosicion`. Diferencia con NSX2: el número de factura se busca sin fallar cuando la venta no tiene factura (en la rama con pagos NSX2 lanzaría una excepción).
- `PresetAutoservicio` (4854), `StopPreset` (5007), `AnularPresetAutoservicio`, `EsPosicionHibrida`, `ObtenerPrecioAutoservicio`, `AutorizarAutoservicio`.
  - `StopPreset(comandoArray)`: formato `id|pos|S[|idTurno]`. Con turno solo cancela un preset de ese turno y no mientras surte (igual que NSX2); sin turno cancela cualquiera. Detiene en `Autorizado`, `EsperandoID` o `Surtiendo`, y además en `Espera`/`Listo` si hay una programación activa (el firmware de Prime no tiene `Autorizado`). Si no estaba surtiendo: saca el preset de la cola, baja `ProgramacionPendiente` y, si es una programación de Autoservicio, la pasa a `ProgramacionAnulada`. Siempre levanta `StopPosiocion` (el poll ya envía el stop al MUX). Responde `S|1|OK` o `S|0|<motivo>`.
  - `PresetAutoservicio`: rechaza un segundo `PAS` si ya hay uno en cola (`_posicionProgramacionAutoServicio`), y en la espera distingue tres desenlaces: éxito (`P1|pos|Surtiendo`), el MUX no recibió el preset (la programación salió de la cola con la bandera arriba) y tiempo agotado a los 8 s. En los dos últimos llama `AnularPresetAutoservicio`.
  - `AnularPresetAutoservicio(programacion, motivo, detener)`: saca la programación de la cola, baja `ProgramacionPendiente`, la pasa a `ProgramacionAnulada` (con `ActualizarPosicionProgramacion`), pide el stop solo si se agotó el tiempo, y responde `E|0|<motivo>, intente de nuevo`.
- `AbrirTurnoPOS` (5119), `CerrarTurnoPOS(idPosicion, usuario, password, mac)` (5178, sobrecarga; el de `AutoCT` queda igual), `ValidarPresetsVivosCierre` (5246).

**MODIFICADO** (una línea que ya existía, en el `case "P1"`):
| Línea | Antes | Después |
|---|---|---|
| 4411 | `if (posicion.IdIsla != turno.IdIsla)` | `if (posicion.IdIsla != turno.IdIsla && !EsPosicionHibrida(posicion))` |

Efecto: un vendedor puede vender con el turno de su isla en las posiciones de un dispositivo de autoservicio en modo híbrido; en las demás posiciones sigue la regla de siempre.

**Reglas nuevas en `T1`/`T2` (sobre código agregado en este mismo archivo)**
- `T1` (5150): si el islero ya tiene un turno abierto en cualquier isla, lo reutiliza y responde `T1|1|Turno abierto`; no abre otro ni toca la MAC.
- `T2`: ya no actualiza la MAC del turno.
- `ValidarPresetsVivosCierre` (5255 y 5280): recorre todas las posiciones del lazo (antes solo las de la isla del turno) y, para posiciones de otros lazos, consulta las programaciones activas del turno de los últimos 30 minutos.

**También en este grupo (I1/I2)**
- `LazoComunicacion.cs`, encabezado: dos `using` nuevos, `Estacion.BusinessModels.ContenedorSerializacion` y `Serializador`.
- `Estacion.Pool\Estacion.Poll.csproj`: **referencia nueva** al proyecto `Serializador` (no crea ciclo: `Serializador` solo depende de Core, BusinessModels, Common, DataModels y RecursosIdiomas).
- `Estacion.Clientes\ClientePosicion.cs` (`ImprimirCopiaRecibo`, ruta por evento que usa `I1`): `case TipoTransaccionEnum.Autoservicio` agregado junto a Efectivo y Mantenimiento, y la condición pasa de `== Efectivo` a `== Efectivo || == Autoservicio`, como en NSX2.
- **No se tocó `ImprimirVenta`** (el bloque de venta local de Prime termina con `SetImpresionCredito`, distinto al de NSX2; agregarle Autoservicio mandaría una impresión de crédito casi vacía).

## 5. `Estacion.Core\MixedServices\MixedReciboTurnoService.cs`
- **NUEVO** archivo (98 líneas): `GuardarReciboTurno` (escribe en `dbo.ImpresionTurno`).

## 5b. `Estacion.Core\MixedServices\MixedAutoserviceService.cs`
- **NUEVO** archivo (119 líneas): `EsDispensadorHibrido(idDispensador)` (consulta `Autoservice.Dispositivo.ModoHibrido`; devuelve `false` si el esquema no existe) y `ObtenerPosicionesConPresetVivo(idTurno, minutos)`.

## 6. `Estacion.Core\Estacion.Core.csproj`
- **MODIFICADO** (líneas 99–100): se agregan `<Compile Include="MixedServices\MixedAutoserviceService.cs" />` y `<Compile Include="MixedServices\MixedReciboTurnoService.cs" />`.

## 7. `Estacion.Core\MixedServices\MixedPrecioProductoService.cs`
- **NUEVO** (línea 35): `ObtenerPreciobyIdNivelyProducto(idNivel, idProducto)` (precio activo de un producto en un nivel).

## 8. `Estacion.Core\MixedServices\MixedImpresionPosicionService.cs`
**MODIFICADO** (línea 103, en `ObtenerPosicionesImpresionWIFI`):
- Antes: `WHERE TC.Pk_IdTipoComunicacion = 2 AND I.Activo = 1`
- Después: `WHERE TC.Pk_IdTipoComunicacion IN (2, 4) AND I.Activo = 1`
- La otra consulta con `= 2` (impresora de oficina, línea 585) no se tocó.

## 9. `Estacion.Impresion\ModeloImpresion.cs`
**NUEVO**
- `using System.Collections.Concurrent;` (línea 6).
- Constantes y ayudantes (líneas 28–110): `TipoImpresora56mm`, `CandadoImpresora`, `ImpresoraCaida`, `MarcarImpresora`, `ConectarImpresora` (conexión con tiempo límite de 5 s), `EsImpresora56mm`.
- `ImprimirSocketQR2` (640) y `AsyncEnviarImpresionWIFIQR2` (682), `EnviarEnBloques` (723).

**MODIFICADO** (desde la línea 627 hasta el final, se reemplazaron estos cuatro métodos con el mismo nombre):
| Método | Antes | Después |
|---|---|---|
| `ImprimirSocket` | `Task.Run(() => AsyncEnviarImpresionWIFI(...))` | igual, pero dentro de un `lock` por IP de impresora |
| `ImprimirSocketQR` | `Task.Run(() => AsyncEnviarImpresionWIFIQR(...))` | igual, dentro de un `lock` por IP |
| `AsyncEnviarImpresionWIFIQR` | `new Socket` + `Connect` sin límite, sin cerrar si falla, mensaje solo en consola | conexión con límite, `using` (siempre se cierra), omite si la impresora falló hace menos de 10 s, queda en el log; **los mismos bytes** |
| `AsyncEnviarImpresionWIFI` | igual que el anterior para el socket; texto en UTF-8 con el comando de logo | mismo socket seguro; **si la impresora es de 56 mm** usa relleno de ceros + `ESC @`, CP437 con `ESC R 13` y fuente B; **si no, los mismos bytes de antes** |

## 10. `Estacion.ImpresionPosicion\ImpresionPosicion.cs`
**MODIFICADO** (líneas 276 y 288):
- Antes: `impresora.ImprimirSocketQR(Qrbyte, lazoComunicacionItem);`
- Después: `ImprimirQRWifi(Qrbyte, lazoComunicacionItem, lineasImp[1]);`

**NUEVO** (línea 306): `ImprimirQRWifi`: si la impresora es de 56 mm regenera el QR a 352 puntos y usa `ImprimirSocketQR2`; si no, llama `ImprimirSocketQR` como antes.

## Lo que NO se tocó
Los modelos (`DispPosProgramacionModel` y demás), el EDMX, `ClientePosicion.cs` (incluido `ImprimirVenta`), `ServidorPOS.cs`, `TurnoService` (salvo `ObtenerUltimoTurnoAbiertoByIdIslero` y `ObtenerTurnoAbiertoByIdIsla`, secciones 12 y 13) y los `Auto*` de Prime.

## Base de datos
Aplicados a `EstacionNSX`: scripts 01, 02, 04, 05 y 06 de `Scripts BD Prime` (el 05 se ejecutó el 2026-10-15: crea `TipoComunicacion` 4 `Impresora56`; el 06 el mismo día: `Turnos.Turno.MacTerminal` a `varchar(20)`, ver sección 13).

## 11. Documento del islero con letras (2026-10-15)

Pedido: poder crear un islero con un documento que tenga letras. Cambios, todos con la herramienta de edición directa y compilados:
- `NSX\Ventanas\Administrador\WndIslero.xaml`: `txtCedula` pasa de `NumericOnlyInput` (solo dígitos, convertido a `int`) a un `TextBox` con `MaxLength="20"`, el tamaño de la columna `Turnos.Islero.Cedula` (`nvarchar(20)`).
- `NSX\Ventanas\Administrador\WndIslero.xaml.cs`: se carga con `txtCedula.Text = islero.Cedula`, se guarda con `txtCedula.Text.Trim()` y se valida con `string.IsNullOrWhiteSpace`.
- `Estacion.Core\Servicios\TurnoIsleroService.cs` (`InsertarIslero`): el `catch` ahora pasa la excepción a `LogError(..., ex)`. Antes se perdía el motivo real del fallo al guardar.

**Sin cambiar (límites a tener presentes)**
- `NSX\Views\Administrador\Modulos\Consignaciones.xaml`: `txtIdentificacionIslero` sigue siendo solo numérico; un islero con letras no se podría buscar ahí.
- La HMI del MUX manda el documento con un teclado numérico: un islero con letras no puede iniciar turno por la HMI. Por los comandos `T1`/`T2` del autoservicio sí (el documento viaja como texto).

## 12. Corrección: `T1`/`T2` y la búsqueda del turno abierto del islero (2026-10-15)

**Defecto mío, detectado por el dueño del proyecto.** En `T1` agregué "si el islero ya tiene un turno abierto, reutilizarlo" con `ObtenerUltimoTurnoAbiertoByIdIslero(...) != null`. Ese método (tal como viene de NSX2) **no filtraba por estado**: devolvía el último turno del islero, abierto o cerrado, y si no tenía ninguno devolvía un modelo vacío en lugar de `null`. Consecuencias:
- `T1` siempre respondía "Turno abierto" y **nunca abría un turno**.
- `T2` (que usa el mismo método) tomaba el último turno aunque ya estuviera cerrado, y la comprobación "el usuario no tiene un turno abierto" nunca se cumplía.

**Arreglo (con la herramienta de edición):** `Estacion.Core\Servicios\TurnoService.cs`, `ObtenerUltimoTurnoAbiertoByIdIslero`: la consulta ahora lleva `and Fk_IdEstadoTurno = {Abierto}` y, si no hay turno abierto, devuelve `null`. Los únicos llamadores en Prime eran estos dos (`T1` y `T2`), así que no afecta nada más. Verificado en `EstacionNSX`: el islero 1 (turno abierto) devuelve 1 fila; el islero 2 (solo turnos cerrados) devuelve 0 con el filtro nuevo, mientras el viejo devolvía su último turno en estado 2 (cerrado).

**Nota:** NSX2 conserva el método sin filtro (y su `T2` tiene el mismo problema); no se tocó.

## 13. `MacTerminal` y causa real de los errores de guardado (2026-10-15)

**Error:** al abrir turno por `T1`, `Turnos.Turno` no se guardaba. En `EstacionNSX` la columna `MacTerminal` era `nchar(10)` y una MAC mide 12 caracteres (SQL 8152, truncamiento).

- **Base de datos:** `Scripts BD Prime\06_Turno_MacTerminal.sql` la deja en `varchar(20)`. Solo ensancha (no toca una columna que ya admita 20 o más). Ejecutado sobre `EstacionNSX`; ya estaba en `varchar(20)` tras la segunda pasada (idempotente). Había 0 turnos con MAC guardada. El EDMX declara `varchar(500)`, compatible con una columna de 20.
- **Turno de la isla con dos abiertos:** `Estacion.Core\Servicios\TurnoService.cs`, `ObtenerTurnoAbiertoByIdIsla`: de `GetSingle` (lanza excepción si hay más de un turno abierto en la isla) a `GetAll(...).OrderBy(Pk_IdTurno).LastOrDefault()` (el abierto más reciente; `null` si no hay). Detectado en `ConfigurarPosicion` (`LazoComunicacion`) tras abrir el turno del autoservicio en una isla que ya tenía un turno de vendedor (isla 2: turnos 9217 y 10232). Con un solo turno abierto el resultado no cambia. Lo llaman 24 sitios en 9 archivos (`ImpresionVenta`, `ControlEstacion`, `ClientePosicion`, `LazoComunicacion`, `SateliteServices`, `TurnoCargaDatos`, `Recuperar`, `Turnos`); es el pendiente "GetSingle a GetLast" ya resuelto. Los llamadores que necesiten el turno del vendedor y no el más reciente de la isla deben revisarse.
- **Estados `0x20`–`0x23` según firmware (PosCDG):** `Estacion.Protocolos\ProtocoloCDG\PosCDG.cs`, `ConvierteEstadoNuevo` + método nuevo `EsFirmwareNSX2()` (`_firmwareMux` en `G`, `Z`, `W` o `L`). Con firmware NSX2: `0x20` `EsperandoID`, `0x21` `IdClienteLeido`, `0x22` `Autorizado`, `0x23` `Stop`; con Prime (`S`/`D` o aún sin detectar) quedan `DatosFE`, `ValidarClienteFE`, `ListoClienteCemex`, `EstadoTurno`. **Por qué:** la posición 5 (`WAYNE 03.8`, protocolo NSX2) tras un `PAS` aceptado (16:28:32) pasó a `ListoClienteCemex`; `PollListoClienteCemex` disparó `SubeManija` y `ClientePosicion` anuló el preset activo ("Anula programacion activa", 16:28:33). Con el cambio ese estado se lee `Autorizado` y no entra en el flujo Cemex. Sin cambiar: longitudes de trama de `Listo` (10 bytes con grado en NSX2) y `Autorizado`. Sin probar en el MUX.
- **Tiempo real en la tarjeta de la posición (escritorio):** igual que NSX2 (copia FIRMA), pero con tolerancia a equipos sin tiempo real. (1) `EventManager\Argumentos\PosicionEstadoEventArgs.cs`: campos `DineroReal` y `VolumenReal`. (2) `Estacion.Pool\LazoComunicacion.cs`, `PollSurtiendo`: en cada ciclo con la posición en `Surtiendo` notifica el evento de estado con `GetDineroRealTime`/`GetVolumenRealTime` (el bloque Tankio queda igual). (3) `NSX\Views\Operador\Modulos\Complementos\Posicion\Posicion.xaml.cs`, caso `Surtiendo`: si hay dinero o volumen real mayor que 0 los muestra con el formato de la posición; si no, deja `888888` / `888.888` como antes. Los valores los llena `PosCDG` solo cuando el MUX manda la trama de 26 bytes (la detección con sondeo ya existente); sin tiempo real quedan en 0. NSX2 muestra siempre el tiempo real porque su firmware lo trae siempre. `PosicionMaximizada` no cambia (solo el fondo, igual que en NSX2). Efecto lateral: el evento de estado ahora se repite en cada ciclo de `Surtiendo` (como en NSX2). Compila; sin probar en pantalla.
- **Log:** `Estacion.DAL\Repositorio\RepositoryBase.cs`, `SaveChanges`: el `ApplicationException` ahora conserva la excepción interna y agrega `-> Causa: <mensaje de la excepción base>`. Antes se perdía y el log solo decía "Vea la excepción interna". El appender de log4net escribe `Message` (varchar 7000) y `Exception` (varchar 2000, truncado), así que la causa va al inicio del mensaje de la excepción. Aplica a cualquier repositorio que guarde con `SaveChanges`.

## 14. Comando `C1` (leer identificador de cliente) (2026-10-16)

Referencia de NSX2: `D:\TeamsInsepet\NSX2\Software\NSX2` (la copia vigente). Compila toda la solución; **sin probar con un MUX real**.

**Cómo funciona:** el POS manda `mac|pos|C1|tipo|modo`. Prime guarda `D1|tipo` y activa una bandera; el hilo del poll envía al MUX la trama `0xD1` (pedir leer ese tipo). Cuando el cliente acerca el identificador llega una trama `0xD3` con el serial y la posición pasa a `IdClienteLeido`. El POS repite `C1` y recibe `C1|PENDIENTE` hasta que está leído, luego `C1|1|serial`; entonces el poll confirma al MUX con `0xD4`.

**Tipos activos:** la fila 24 de `dbo.Configuracion`, `IDCliente` (descripción `Ibutton|Tag|Teclado|BandaMagnetica|CodigoBarras|CodigoQR|Tag Multilectora`, valor `1|0|1|1|1|0|0`). `C1` rechaza con `E|0|El tipo de identificador no esta activo en la estacion` un `tipo` cuya bandera sea 0. `tipo` es la posición en esa lista (1 a 6; la trama `D1` de NSX2 no admite el 7). Prime ya manda esas banderas al MUX con `EnviarIDCliente` (`0xC3`) y ya tiene la ventana `WndIDCliente`.

- `Estacion.BusinessModels\Models\PosicionPoolDatosModel.cs`: banderas `EnviarComandoPOS` y `SerialRecibido`.
- `Estacion.DataModels\Enumeraciones\TipoIdentificadorClienteEnum.cs`: se agregan `TarjetaInteligente` 5, `CodigoBarras` 6, `TagMultilectora` 7 y `RFID` 8 (como NSX2). Ojo: el número del enum no es la posición en `IDCliente` (ahí el Teclado es el 3.º y en el enum vale 4); NSX2 los traduce con un `switch` en `AutorizarCliente` (parte de `C2`, pendiente).
- `Estacion.Protocolos\IPosicion.cs` (`EnviarComandoPOS`, `SerialRecibido`) y `PosEmr3.cs` (sin soporte, como NSX2).
- `Estacion.Protocolos\ProtocoloCDG\PosCDG.cs`: trama `0xD3` en los dos cálculos de largo (8 bytes más el largo del serial) y en el despacho (`CapturarIdClente` deja el serial y marca `IdClienteLeido`); métodos `CapturarIdClente`, `EnviarComandoPOS` y `SerialRecibido`. **Diferencia con NSX2:** `EnviarComandoPOS` no envía nada si el tipo no es 1 a 6 (NSX2 mandaba la trama sin el byte de tipo); tampoco registra tramas a archivo (`LoggerTxt` no existe en Prime).
- `Estacion.Pool\LazoComunicacion.cs`: diccionario `_comandoPOS` por posición; en el poll, envío del comando y de `SerialRecibido` (dos puntos, como NSX2); caso `C1` en `ComandoPOS` y método `LeerIdentificadorCliente`.

La posición debe leerse por el MUX (no marcada `AutoServicio`) y el firmware debe soportar `0xD1`/`0xD3`.

## 15. Comando `C2` (autorizar cliente a crédito/prepago) (2026-10-16)

Igual que NSX2 (`D:\TeamsInsepet\NSX2\Software\NSX2`), sin tocar el poll. Compila toda la solución; **sin probar con un MUX real**.

**Formato:** `mac|pos|C2|tipoPreset|grado|valor|placa|km|serial|clave|tipoIdentificador|idConductor|turno`. `tipoIdentificador` es la posición en `IDCliente` (el teclado, 3, lleva `serial~clave`). Respuesta `C2|1|Vehiculo Autorizado Placa: …\nCuenta: …\nProducto: …` o `E|0|motivo`.

**Flujo (como `AutorizarCliente` + `OperacionesPOS.AutorizarCliente` de NSX2):** estado de la posición (`Espera`, `Listo` o `IdClienteLeido`) y turno → identificador activo por trama → validación con `ClienteLocalPOS` (cuenta, vehículo, conductor, restricciones y saldo; deja nivel, precio y tipo de transacción según la cuenta) → corte en curso → inserta la programación y, si es prepago o crédito local, descuenta el saldo y lo registra en el histórico → `ProgramarAutoServicio` + evento. No espera la confirmación del MUX.

- **NUEVO** `Estacion.Pool\ClienteValidacion\ClienteLocalPOS.cs`: copia verbatim del de NSX2 (`Estacion.OperacionPOS\ClienteLocalPOS.cs`), solo con el `namespace` cambiado a `Estacion.Poll.ClienteValidacion`. Se eligió una copia separada de `ClienteLocal` (el de la HMI, en `Estacion.Clientes`) porque `Estacion.Clientes` ya depende de `Estacion.Poll` y un ciclo no compila; así no se toca la HMI. **MODIFICADO** `Estacion.Poll.csproj` (el `Compile`).
- **MODIFICADO** `Estacion.Pool\LazoComunicacion.cs`: `using Estacion.Poll.ClienteValidacion`; caso `C2`; métodos `AutorizarClientePOS`, `ValidarTurnoPreset` y `ActualizarSaldoLocalInicioVenta` (copia de la de `ClientePosicion`, que es privada de esa clase).

**Diferencias con NSX2, a propósito:**
- `ValidarTurnoPreset` permite el turno de otra isla en un dispensador híbrido (igual que `P1` de Prime).
- Preset "lleno" (`tipoPreset` 1): `ValorProgramado` es el límite de dinero de la posición (como `P1`/`PAS`); NSX2 manda el valor tal cual.
- Si ya hay un preset en cola en la posición responde error; sin eso el segundo `C2` insertaría la programación y fallaría al encolar.
- Sin `ValidarCorteBloqueante` (Prime no tiene corte bloqueante), sin cliente web (satélite/master online), sin tercero BoteroSoto, sin `MacTerminal`/`IsleroAux` (columnas descartadas) y sin el ticket "SERIAL LEIDO" que NSX2 imprime al fallar (en autoservicio se imprime solo a demanda).
- Se revirtió un intento de compartir la espera al MUX con `PAS`: `PAS` quedó exactamente como estaba.
- **Placa:** `ClienteLocalPOS` no la pone en la programación (en NSX2 se guarda la que manda la app). Como el API ya no la exige, si llega vacía se toma la del vehículo del identificador; la respuesta usa la placa del vehículo (como NSX2).

## 16. El turno de la programación no se pisa (2026-10-16)

**Síntoma (venta 628362, `P1` de un vendedor en un dispensador híbrido):** el API mandó el turno del vendedor (10234, isla 4) pero la programación 631486 y la venta quedaron con el turno 10233 (el del autoservicio, isla 2).

**Causa:** `Estacion.Clientes\ClientePosicion.cs`, `ValidarTurno`, asignaba siempre `programacion.IdTurno = ObtenerUltimoTurnoIsla(isla de la posición)`, aunque la programación ya trajera turno. El `ValidarTurno` de NSX2 solo lo hace `if (programacion.IdTurno == null)`.

**Cambio (como NSX2):** la condición pasó de `programacion.IdIsla != null` a `programacion.IdIsla != null && programacion.IdTurno == null`. Las programaciones de la HMI (sin turno) se comportan igual que antes; las que traen turno (`P1`, `PAS`, `C2`) lo conservan. No se portó la rama de turno libre por MAC de NSX2 (`ObtenerUltimoTurnoIslaMacTerminal` no existe en Prime).

**Datos de la venta 628362:** quedaron con el turno 10233 (programación 631486 y detalle de venta). La corrección del código no los cambia.

## 17. Fidelidad: comandos `F1` y `F2` (2026-10-16)

`Estacion.Pool\LazoComunicacion.cs`: `case "F1"` (validar cliente) y `case "F2"` (fidelizar venta), copiados de NSX2 solo para LifeMiles y Commodo. Métodos nuevos: `ObtenerSistemaFidelidad`, `ValidarClienteFidelidad`, `FidelizarVenta`, `AcumularFidelidadVentaAnterior`, constante `EsperaAcumulacionFidelidadMs` (12000).

- **Ids de fidelidad (API):** 1 PuntosColombia, 2 LifeMiles (se muestra "ViveTerpel"), 3 Commodo, 4 Local, 5 Leal. Prime solo acepta 2 y 3; los demás responden `F1|0|` / `F2|0|Programa de fidelidad no soportado`.
- **Campo 6 (2026-10-16, ya aplicado):** igual que NSX2 es el **nombre** del programa (`LifeMiles` o `Commodo`); cualquier otro responde `|0|Programa de fidelidad no soportado`. El API traduce el id a nombre, así que NSX2 y Prime reciben el mismo comando.
- **F2 con venta anterior (la que se usa):** inserta la fila en `Fidelidad.VentaFidelizada` y acumula de una (LifeMiles con `AcumularPuntosSatelite`, Commodo con `AcumularVentaCommodo`). Espera hasta `EsperaAcumulacionFidelidadMs` (los servicios web usan `Timeout = -1`). Responde `F2|1|<cliente> Acumulacion Millas: <n> millas` si acumuló; `F2|0|<motivo>` si falló o el programa rechazó; `F2|0|La acumulacion sigue en proceso...` si pasó el tiempo (la tarea sigue y deja el resultado en `VentaFidelizada`).
- **Éxito de LifeMiles** = estado `VentaCerrada` **y** millas no nulas (`SateliteServices.AcumularFidelizarVenta` devuelve `true` aun con error de negocio y NSX2 deja esa fila como cerrada con "Transaccion Exitosa").
- **Diferencia con NSX2 (Commodo):** NSX2 acumula con los datos de la **última fila existente** y luego inserta la nueva; aquí se inserta primero y se acumula con el documento recibido.
- Las excepciones responden `F2|0|Error: ...` (NSX2 responde `F2|1|Error: ...`).
- **NSX2: a medias.** Solo se editó la rama LifeMiles/venta anterior de `FidelizarVenta` (llama a `AcumularFidelidadVentaAnterior`, que **no existe** en NSX2; hay un comentario PENDIENTE). **NSX2 no compila hasta copiar el método, cambiar la rama de Commodo y los `|1|Error` a `|0|Error`.**
- Compilado en carpeta temporal; `NSX.exe` **no** se reconstruyó con esta última parte.
- **Campo 9 de F2 (opcional):** `idVenta` a fidelizar; sin él se usa la última venta de la posición. La fidelización queda en la posición de la venta.
- **Columna `Fidelidad.VentaFidelizada.Fk_IdFidelidad`** (2026-10-16, ya creada en `EstacionNSX`): programa de cada fidelización (1 PuntosColombia, 2 LifeMiles, 3 Commodo, 4 Local, 5 Leal). Se escribe con `MixedFidelidadService.AsignarProgramaFidelidad` al empezar a acumular: `ModeloWeb.AcumularPuntosSatelite` (2), `AcumularVentaCommodo` (3), `FidelizarVentaLeal` (5) y `ClientePosicion.AsyncAcumularVentaFidelidadLocal` (4). Pendiente en NSX2.

## 18. El valor programado no aparecía en `C2`/`PAS` (2026-10-16)

**Síntoma:** al enviar un preset de efectivo (`P1`) el tile de la posición mostraba el valor programado; con crédito (`C2`) y autoservicio (`PAS`) no.

**Causa:** `C2` y `PAS` notifican `LazoComunicacion._programacionEventHandler[idPosicion]` (`EventoProgramacionInsertada`), pero Prime no tenía a nadie escuchando ese evento. `P1` pasa por el evento propio de `ClientePosicion`, que sí está conectado. NSX2 conecta la interfaz con `AttachProgramacionInsertada`.

**Cambio (copiado de NSX2):** `AttachProgramacionInsertada` en `ModeloEstacionPoll`, `ModeloSincronizacionPoll` y `ControlEstacion`, y las dos llamadas en `NSX\Views\Operador\Modulos\Estacion_NSX.xaml.cs` (posición minimizada y maximizada). Compila; **requiere reconstruir `NSX.exe`**.

## 19. `PollListo` con firmware NSX2 (2026-10-16)

**Síntoma (log, posición 5, 13:28:04):** con el MUX en `Listo`, `Programacion Posicion 5 Valor programado 0 TipoProg 0` → `Error al insertar programacion de la posicion` (FK `FK_DispensadorPosicionProgramacion_TipoProgramacion`, tipo 0) → `Error al completar la programacion` → `No es posible anular la programacion…` (no hay nada que anular), cada ~0,4 s mientras siga en `Listo`.

**Causa:** con el HMI de Prime (firmware S/D) `Listo` es un preset programado desde el MUX y `PollListo` arma la programación con él. Con firmware tipo NSX2 (G, Z, W, L) `Listo` solo significa manguera levantada, sin preset. El `PollListo` de NSX2 no arma programación (solo envía programación cero con `AutorizaSiempre`).

**Cambio:** `IPosicion.GetFirmwareMux()` (en `PosEmr3` devuelve `'\0'`) y, al inicio de `LazoComunicacion.PollListo`, `return` si el firmware es G, Z, W o L (sin la rama de `AutorizaSiempre` de NSX2). Con S/D no cambia. Compila; **requiere reconstruir `NSX.exe`**.

**Teclado en `C2` (2026-10-16):** los identificadores de teclado de Prime se guardan como `serial|clave cifrada` (`EncriptionHelper.Encrypt`, igual que el HMI en `LazoComunicacion`), no como `serial~clave` (forma del `C2` de NSX2). `C2` con tipo 3 busca primero `serial|Encrypt(clave)` y, si no hay, `serial~clave`. Caso real: identificador 47 (`INS002|…`) respondía "Identificador no registrado o inactivo". Compila; **requiere reconstruir `NSX.exe`**.

**Pendiente de aclarar:** la petición de totales después de cada venta (`ValidarVentaPendiente`) es lógica original (igual en NSX2); en el entorno de prueba los totales de la BD no coinciden con los del surtidor (grado 11: 272397 vs 856).
