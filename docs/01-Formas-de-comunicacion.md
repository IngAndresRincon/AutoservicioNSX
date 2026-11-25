# Autoservicio en NSX Prime: de la HMI del MUX a pantalla Android + API

Estado: borrador 2 (2026-10-14). **[CONFIRMAR]** = deducción mía sin verificar.

## 1. Alcance

- **Se adapta lo que ya existe en NSX2 a NSX Prime** y se agrega que **el islero venda desde la pantalla**.
- **Fuera de alcance:** Petromil (`D:\AUTOATENDIDO\Petromil-NSX`) y `NSX2-PR` no se tocan. La Orange Pi y su código son de otro compañero; aquí solo se **publican endpoints**.
- **Fase 1: vender** (turno, preset, estado, stop, formas de pago, impresión). Fidelidad y Facturación Electrónica van después.
- El API sigue **sin autenticación** por ahora.
- `ModoHibrido` es un **parámetro de configuración** (sección 6).
- Se revisan de paso la app Flutter (incluir híbrido y depurar) y el admin web de mapeo.

## 2. Contexto: qué cambia

Hoy en NSX el **MUX** tiene una **HMI** que va directo al hardware. Lo que llega por **PosCDG** (`IPosicion` / `EstadoSurtidorEnum`) dispara acciones en `LazoComunicacion`: la HMI pide turno, digita el preset, escoge forma de pago, pide copia de recibo, etc.

En autoservicio se **quitan esas HMI y se ponen pantallas Android**. Todo lo que la HMI enviaba o hacía ahora se pide con **comandos TCP** que expone un API REST. NSX2 ya resolvió esto con comandos nuevos (`T1`, `T2`, `PAS`, `E`, `S`, `I1`, `I2`, ...); Prime todavía depende de la HMI.

```
Android / Orange Pi ──REST──> NSXAutorserviceAPI ──TCP cifrado (ServidorPOS 8010)──> NSX ──PosCDG──> surtidor
                                      └──SQL directo──> EstacionNSX
```

**Confirmado:** el MUX sigue controlando el surtidor y NSX le envía por PosCDG (programar, estado, totales). Solo desaparece la HMI como interfaz con el islero. Por ahora no se cambia el control del surtidor (ver sección 12 sobre LEOS).

## 3. Qué hacía la HMI y quién lo reemplaza

Evidencia: `IPosicion`, `EstadoSurtidorEnum` y `LazoComunicacion` de Prime; `ComandoPOS` de NSX2.

| Función de la HMI (MUX) | Señal en Prime | Reemplazo en NSX2 (comando) | Endpoint API | En Prime hoy | Fase |
|---|---|---|---|---|---|
| Abrir / cerrar turno del islero | `PeticionTurno` → `CargaDatosTurno` → `RespuestaTurno` (lógica en el poll, ~líneas 2500–2680) | `T1`, `T2` (`AbrirTurnoPOS`, `CerrarTurnoPOS` con usuario, clave y MAC) | `Turno/ValidarVendedor`, `AbrirTurno`, `CerrarTurno` | Solo `CerrarTurnoPOS(idPosicion)` con otra firma. No hay `AbrirTurnoPOS` | 1 |
| Digitar preset (valor, placa, km) | `GetProgramacion`, `GetPlacaDigitada`, `GetKilometraje`, `GetValorPreset` | `PAS` → `AutorizarAutoservicio`: inserta `DispPosProgramacion` (tipo Autoservicio, nivel "Autoservicio") y programa | `Preset/Preset` | Existen `P1`, `ProgramarAutoServicio`, `PollAutoServicio` y el estado `ListoAutoServicio`. **No existe `PAS` ni `AutorizarAutoservicio`** | 1 |
| Estado y venta en tiempo real | HMI lee el display | `E` (usa `GetDineroRealTime`, `GetVolumenRealTime`, `GetGradoRealTime`) | `Preset/EstadoPreset`, `ObtenerEstado` | `IPosicion` los tiene, pero no hay `case "E"` | 1 |
| Detener / cancelar preset | `Detener`, `StopPosicion`, estado `Stop` | `S` | `Preset` (cancelar) | Existe `StopPosicion`; no hay `case "S"` | 1 |
| Escoger forma de pago | `EnviarBotonesFormasPago`, `GetObtenerFormaPago`, `RealizarFormaPago` | El API inserta `FormaPago.DetalleFormaPagoAutoServicio` tras el preset | `Preset` (formas de pago) | **Ya existe** modelo, tabla y consumo (`MixedFormaPagoCombustibleService`, casi igual a NSX2) | 1 |
| Imprimir recibo / copia | `PeticionCopiaVenta`, `gImprimirEfectivo`, `gImprimirGeneral` | `I1` (última copia), `I2` (por `idVenta`) → `SolicitarCopiaRecibo` | `Impresion/ImprimirVenta` | No existen `I1`, `I2` ni `SolicitarCopiaRecibo` | 1 |
| Fin de venta / reporte | `ReporteVenta`, `PedirFinVenta`, `ListoTotales` | Interno de NSX; el API consulta la venta por preset | `Venta/preset/{id}`, `ultima` | Ya existe en NSX | 1 |
| Corte bloqueante | n/a | `ValidarCorteBloqueante` dentro de `PAS`, `P1`, etc. | n/a | **No existe** en Prime | **Fuera por ahora** |
| Vueltos (efectivo con cambio / QR) | n/a | `Autoservice.Vueltos`, `MixedAutoserviceService` | `Vueltos/*` | **No existe** (`MixedAutoserviceService`, `AutoservicioVueltosModel`, total de vueltos por turno) | **Fuera por ahora** |
| Totales | `gPedirTotales` | `TT` | n/a | Hay `PedirTotales`, no `case "TT"` | Opcional |
| Identificar cliente / fidelidad / FE | `EnviarIDCliente`, `ValidarClienteFidelidad`, `DatosFE`, `ValidarClienteFE` | `CFE`, `PCV`, `VT`, `CMD`, `LOCAL`, `LEAL`, `QR`, `FP` | `Facturacion`, `Fidelidad` | Parcial | 2 |
| Config y logo de la HMI | `SetConfiguracionPosicion`, `EnviarLogo` | Lo reemplaza `Mapeo/ObtenerMapeo` y `ObtenerPrecios` | `Mapeo/*` | n/a (se sirve desde la BD) | 1 |
| Reset / versión / pitar | `ResetMux`, `VersionMux`, `Pitar` | n/a | n/a | n/a | No aplica a la pantalla |

Estados de la HMI que dejan de tener sentido con Android **[CONFIRMAR con el MUX conservado]**: `EsperandoID`, `IdClienteLeido`, `SolicitandoDatosCopiaVenta`, `EsperandoInfoAdicionalCliente`, `PasswordRedencionLeal`, `RealizarFPVoucherTerpel`. Se anotan para decidir si se desactivan en posiciones de autoservicio.

## 4. Formato de los comandos TCP (fase 1)

`identificador|idPosicion|COMANDO|campos...` (ASCII, `|`). Con `Sistema = NSX` va cifrado. El `identificador` es la MAC del terminal y `ServidorPOS` lo valida contra terminales activas. Error: `E|0|mensaje`.

| Cmd | Formato | Respuesta |
|---|---|---|
| `E` | `id\|pos\|E\|` | `Estado\|dinero\|volumen\|gradoRT\|gradoPreset` (según estado) |
| `PAS` | `id\|pos\|PAS\|tipo\|manguera\|valor\|placa\|km\|tel\|\|\|idTurno` — tipo 1=full, 2=dinero, 3=volumen; `idTurno` 0/vacío = sin turno | `P1\|pos\|Surtiendo` o `E\|0\|...`; el API espera la programación en BD hasta 10 s |
| `S` | `id\|pos\|S` | `x\|1\|..` = no se pudo cancelar |
| `T1` / `T2` | `mac\|pos\|T1\|documento\|password` | texto o `E\|0\|..` |
| `I1` / `I2` | `mac\|pos\|I2\|idVenta\|tipoTransaccion` | OK o `E\|0\|..` |

## 5. Respuestas largas (a verificar)

- API: una lectura con buffer fijo de **500 bytes**.
- `ServidorPOS`: recibe en buffer de **200 bytes** con una sola lectura, y si el comando pasa de 400 caracteres le quita los últimos 400.
- Propuesta: lectura en bucle con terminador o prefijo de longitud, compatible hacia atrás. Primero medir qué respuestas reales superan esos tamaños (p. ej. `E` con textos de error, recibos).

## 6. Modo híbrido

**Decidido:** se define **por dispositivo** en `Autoservice.Dispositivo`. Hoy esa tabla tiene `IdDispositivo`, `Identificador` (MAC de 12 caracteres), `IdDispensador`, `Ip`, `Activo`, `FechaRegistro` (según `Consultas.cs`). **Falta agregar la columna del modo** (propuesta: `ModoHibrido BIT NOT NULL DEFAULT 0`), exponerla en `DispositivoModel`, `ObtenerDispositivos`, `GuardarDispositivos` y en el admin web, y que la app la reciba con el mapeo.

- **Autoservicio puro:** el cliente hace todo; la venta se reporta al **usuario de autoservicio**.
- **Híbrido:** además el islero se loguea en la pantalla (`ValidarVendedor` → `T1`) y **obtiene su turno**. Los presets que haga el islero se envían con **su** turno (campo `idTurno` de `PAS`).
- Abrir o cerrar el turno del islero **no apaga** el autoservicio.

Reglas de NSX a respetar:
- Un turno abierto por islero → el **usuario de autoservicio debe ser un islero distinto** de los vendedores.
- El cierre `T2` resuelve por credenciales, no por MAC.
- `PAS` hoy toma el turno por MAC (`ObtenerIdTurnoByIdentificador`); en híbrido con islero logueado debe usar el turno del islero.

## 7. Scripts para Prime

Base: `Historico Scripts\124. Modulo Autoservicio NSX2.sql` (NSX2 V 3.0.3). Crea el esquema `Autoservice` (`Configuracion` con `Bandera`/`Sistema`/`MaxVueltos`, `Dispositivo`, `EstadoVueltos`, `Fidelidad`, `FormaPago`, `Recursos`, `Vueltos`), `dbo.Bandera`, `FormaPago.DetalleTransaccion`, los tipos de transacción Tankio y Autoservicio (22 y 23), los niveles "Tankio" y "Autoservicio" y `TipoComunicacion` 4 (`Impresora56`).

**Revisión: lo que falta o no sirve tal cual para Prime**

1. **IDs de `TipoTransaccion` distintos entre NSX2 y Prime.** En NSX2: `Tankio = 22`, `Autoservicio = 23`. En el código de Prime: `Tankio = 19`, `Autoservicio = 20` (y `Tappsi`, `ControlPrivada`, `Control`, etc. no existen o tienen otro id). El script 124 insertaría 22 y 23, que en Prime no significan eso. **Hay que usar los ids de Prime** y revisar qué otros ids del API o la app suponen 23. Es el punto más delicado.
2. **El script no es idempotente.** `CREATE SCHEMA` y `CREATE TABLE` sin `IF NOT EXISTS`, `INSERT` de tipos de transacción y de `TipoComunicacion` sin guarda, y el `raiserror` de "ya existe" no detiene nada. Hay que reescribirlo para Prime.
3. **`FormaPago.DetalleFormaPagoAutoServicio` no la crea ningún script.** El 124 solo le pone una FK. Ningún script del histórico la crea, así que viene en la base. El código de Prime sí la usa. **Hay que confirmar en una BD de Prime que exista** con las columnas que usa `MixedFormaPagoCombustibleService`.
4. **Columnas previas en `DispensadorPosicionProgramacion` (y su histórico) y `Turnos.Turno`**, que el 124 no trae y vienen de otros scripts del histórico:
   - `MacTerminal` (`15. Turno Libre.sql`, también en `Turnos.Turno`), `TelefonoCliente` (`16`), `IdIsleroAux` (`96`), `InfoExtra` y `SerialConductor` (`77`).
   - El modelo de Prime ya las espera; falta confirmar que la BD las tenga.
   - `AutorizarAutoservicio` escribe `MacTerminal` y `TelefonoCliente`, así que son obligatorias.
5. **Registro de la MAC en `dbo.Terminal`.** En NSX2, `ServidorPOS` solo acepta comandos de MACs que estén en `dbo.Terminal` (se guarda cifrada); en Prime esa validación está comentada. El API guarda el dispositivo solo en `Autoservice.Dispositivo`. **Falta el paso que registre la MAC del dispositivo también en `dbo.Terminal`** (hoy existe `InsertarTerminal` en `ComunicacionPOSService`; a decidir si lo hace el API, el admin web o un script).
6. **Configuración `IPNsxAPI`** (IP|puerto) en `dbo.Configuracion`: el 85 la crea en NSX2. El `ConfiguracionEnum` de Prime **no tiene `IPNsxAPI`**; el API la lee por SQL, así que basta el registro.
7. **`ModoHibrido`:** no existe; agregar la columna a `Autoservice.Dispositivo`.
8. **`dbo.Bandera`:** puede ya existir en Prime; crearla solo si falta.
9. **Datos semilla ausentes:** el 124 no llena `Autoservice.FormaPago`, `Fidelidad` ni `Recursos` (se llenan desde el admin). Verificar si hace falta una semilla mínima.
10. **Fuera de la fase 1:** `Autoservice.Vueltos` y `EstadoVueltos` (se pueden crear vacías para que el API no falle), y lo de facturación/fidelidad (`FElectronica.*`, `PuntosColombia.*`).
11. **Tipos y largos a unificar:** el 124 usa `Dispositivo.Identificador VARCHAR(100)` y `MacTerminal VARCHAR(500)`; el API exige MAC de 12 caracteres.

**Siguiente paso:** con el `.bak` de Prime (o una BD de prueba) comparar qué de esto ya existe antes de redactar el script de Prime. Sin conectarme a ninguna BD: ¿tienes una BD de Prime restaurada donde pueda ver el esquema, o prefieres sacarme un listado de tablas y columnas?

## 8. App Flutter (`gnesys_as`)

- Sesión y pantalla de venta para islero bajo `ModoHibrido`.
- Hoy llama a **dos familias** de rutas: `/api/Estado`, `/api/Mapeo` (este API) y `/nsx-autoservice-api/V1/...` (que este API no tiene). Unificar.
- Pantallas muy grandes a partir: `payment_screen` (2083 líneas), `transactions_screen` (1956), `identification_screen` (1726).
- Depurar, verificando uso antes de borrar: `socket_io_client`, `camera`, `mobile_scanner`, `gif`, `lottie`, `open_file`, `android_intent_plus`, servidor REST local de videos, `build/` versionado.

## 9. Admin web (`autoservice-admin`)

React + Vite. Páginas: Mapeo (678), Configuración (2176), Turnos, Colores, Publicidad, Reportes (1987), Login. Revisar Mapeo contra el flujo nuevo, exponer `ModoHibrido` y decidir qué páginas siguen vigentes. `services/api.js` es mínimo; las llamadas están dentro de las páginas.

## 10. Hallazgos para más adelante

- `appsettings.json` del API tiene IP y contraseña `sa` en texto plano, versionado en git.
- CORS abierto y `UseHttpsRedirection` activo.
- `PROTOCOLO NSX-MUX.xls` no es necesario: la tabla de la sección 3 sale del código (`IPosicion`, `PosCDG`, `LazoComunicacion`) y no cambia el trabajo, porque el control del surtidor no se toca.

## 11. Orden propuesto (ver también la sección 12)

1. Cerrar este documento con tus respuestas.
2. Matriz de paridad detallada de la fase 1, comando por comando, y **tu aprobación antes de editar** cada archivo de Prime.
3. Scripts de BD.
4. Portar `T1`/`T2`, `PAS` (+ `AutorizarAutoservicio`), `E`, `S`, `I1`/`I2` a `ComandoPOS` de Prime.
5. `ModoHibrido` en API y config.
6. Flutter y admin web.
7. Prueba en una estación.
8. Fase 2: fidelidad y Facturación Electrónica.

## 12. Idea abierta: LEOS (`D:\NSXCloud`) en el dispensador

**Qué es LEOS** (según el código en `D:\NSXCloud`): una versión reducida de NSX para Linux/Orange Pi. Trae su propio `LazoComunicacion`, `ServidorPOS` (puerto 8010) y `PosCDG` (copia del protocolo CDG por serial, 9600 8N1), con BD Postgres (`nsxautoservicio`). Encima va **ApiNSXCloud**, un REST con `api/posicion/{id}/estado|totales|preset|stop|continuar-preset|id-cliente`, `api/hardware/{id}/version|reset|configuracion-mux`, `mapeo`, `precios` y `ventas`.

**Qué NO es:** no reemplaza al MUX. LEOS también le habla al MUX por CDG. Lo que cambia es **dónde corre el polling**: en una caja junto al dispensador en vez de en el servidor NSX.

**Qué no tiene** (por los comandos que vi: `C`, `CM`, `CP`, `DINERO`, `E`, `FULL`, `P`, `Pr`, `R`, `S`, `T`, `V`, `VOLUMEN`): turnos, formas de pago, impresión de recibos, facturación ni cortes. Eso sigue siendo lógica de NSX.

**Cómo encajaría con NSX Prime:** NSX ya abstrae el control del surtidor: `LazoComunicacion` guarda un `IPosicion` por posición, creado según `ProtocolosEnum` (`Gilbarco` → `PosCDG`, `Emr3` → `PosEMR3`). LEOS sería un tercero (`PosLeos`) que, en lugar de hablar serial, llame a ApiNSXCloud. Los comandos de la sección 4 viven por encima de `IPosicion`, así que **todo lo de esta fase se reutiliza igual**.

| | PosCDG directo (hoy) | PosLeos (idea) |
|---|---|---|
| Hardware | Serial del servidor NSX al MUX | Caja LEOS junto al dispensador + red |
| Polling | Local, rápido | NSX consultaría el estado por HTTP: más pesado y con latencia |
| Fuentes de verdad | Una (SQL Server de NSX) | Dos (Postgres de LEOS y SQL Server de NSX); hay que reconciliar ventas |
| Trabajo nuevo | Ninguno | Driver `PosLeos`, eventos de fin de venta, manejo de caída de red |
| Ventaja | Simple | Evita cableado largo al servidor; la caja puede operar sola |

**Conclusión:** la idea no quita trabajo de la fase 1 ni elimina el MUX. Es válida como línea futura si el problema a resolver es cableado o autonomía por dispensador. Se hace primero por PosCDG (acordado); `PosLeos` queda como evaluación aparte.

## 13. Revisión de la BD local `EstacionNSX` (2026-10-15)

Se exportó con `Esquema-Exportar.sql` a `esquema_EstacionNSX.txt` (SQL Server 16, solo lectura). Es de la línea **Prime**: `TipoTransaccion` 19 Tankio / 20 Autoservicio, nivel "Autoservicio" id 8, 22 esquemas, 1590 columnas, 190 objetos programables.

**Ya tiene (no hay que crearlo)**
- `FormaPago.DetalleFormaPagoAutoServicio` (con `Pk_IdFormaPagoAuto`, `Fk_IdPosicion`, `Valor`, `Identificador`, `Fk_IdTipoCompra`, `Fk_IdFormaPago`, `Fk_IdTurno`, `Fk_IdPosicionProgramacion`, `Fecha`).
- `dbo.DispensadorPosicion.Autoservicio`, `Turnos.Turno.MacTerminal`, `dbo.DispensadorPosicionProgramacion.Fk_IdTurno`, `InfoExtra`, `SerialConductor`.
- Config `AutoServicio`, `CorteBloqueante`, `IPNsxAPI` (id 55), `AutorizarKm0`, `ImpValidCliente`.
- Tipos de transacción 19/20 y nivel Autoservicio: **no se deben insertar 22/23**.

**Tiene huellas del script de Petromil** (`AutoAtendidoVenta`, `DianResolucion`, `LogVentaRecuperada`, `TipoMetodoPago`, y las configs `UsuarioPetromil`, `PasswordPetromil`, `CodigoEDSPetromil`). Hay que decidir si esta BD sirve como base "Prime" o si hay una limpia.

**Falta para el autoservicio (fase 1)**
| Pieza | Origen | Para qué |
|---|---|---|
| Esquema `Autoservice` completo (7 tablas) | Script 124 | Dispositivos, formas de pago, config, recursos |
| `dbo.Bandera`, `FormaPago.DetalleTransaccion` | 124 | Mapeo y pagos con tarjeta |
| `dbo.Terminal` | Script 1 | NSX2 valida la MAC contra esta tabla. **En Prime esa validación está comentada en `ServidorPOS`, así que hoy no bloquea**; hace falta solo si se reactiva |
| `dbo.MuxConfiguracion` | Script 2 | Configuración del MUX (usada por el API de hardware) |
| `DispensadorPosicionProgramacion`: `MacTerminal`, `TelefonoCliente`, `IdIsleroAux` | Scripts 15, 16, 96 | `AutorizarAutoservicio` los escribe |
| `Historico.HistoricoDispensadorPosicionProgramacion`: las mismas más `SerialConductor` | 15, 16, 77, 96 | El trigger `InsertarProgramacion` copia al histórico |
| Trigger `InsertarProgramacion` del 96 | 96 | Copia `IdIsleroAux`/`MacTerminal`/`TelefonoCliente` al histórico |
| `dbo.ImpresionTurno` | Script 14 | Recibo de turno (probable en `T1`/`T2`) |
| Config `TurnoLibre` | Script 15 | `T2` resuelve por credenciales |
| `Autoservice.Dispositivo.ModoHibrido` | Nuevo | Modo híbrido |

**Otros faltantes de NSX2 detectados** (no son del autoservicio, pero muestran el desfase): `Archivos.*`/`ConfiguracionFirma` (129), `Controller.*`, `FidelidadLocal.*`, `Corte.Meta`/`HistorialMeta`, `Primax.*`, `PuntosColombia.*`, `Tercero.*`, `VeederRoot.Alertas`/`Configuracion`, `Sms.Configuracion`, `Correo.Configuracion`, `FElectronica.Remision`, `Venta.Sincronizado`, `Islero.VendedorCredito`, `Canasta.ObtenerIslaPorPosicion`, entre otros. La lista completa se saca cruzando el histórico (scripts 1 a 130) contra el esquema exportado.

**Límites de esta comparación:** es heurística. Lee `CREATE TABLE`, `ALTER TABLE ... ADD` y `CREATE/ALTER` de SP, trigger y función. Subcuenta columnas cuando un script agrega varias en una sentencia, y no detecta tablas que scripts posteriores renombraron o borraron. Hay que revisar cada faltante antes de incluirlo.

**Método reutilizable:** exportar cualquier BD con `Esquema-Exportar.sql` y compararla contra otra o contra el histórico. Esto cubre la BD en blanco que falta.

## 14. Matriz de paridad de la fase 1 (NSX2 → Prime)

Decisión: la BD base es la local `EstacionNSX`; el trabajo de base de datos se hace **al final**, cuando el autoservicio esté listo. Esta matriz no edita nada: es para que apruebes qué se porta.

**Evidencia nueva sobre los `Auto*` de Prime:** `AutoPreset` documenta que la fecha de la venta la "reporta AutoAtendidoAPI" y recibe dinero y volumen iniciales. Es un modelo de **reporte posterior** (la venta ya ocurrió y NSX solo la registra), distinto de `PAS` (NSX programa el surtidor). Es la familia Petromil/AutoAtendidoAPI: **no se toca**. Además, `CerrarTurnoPOS(idPosicion)` de Prime tiene un defecto propio: en la rama donde no hay turno abierto usa `turnoAbierto.IdIslero` con `turnoAbierto == null`, lo que lanzaría `NullReferenceException`. No se arregla en este alcance, solo se deja anotado.

### Piezas de Prime que se reutilizan tal cual
`ProgramarAutoServicio(DispPosProgramacionModel)` (público), `PollAutoServicio` y estado `ListoAutoServicio`; `GetDineroRealTime`/`GetVolumenRealTime`/`GetGradoRealTime` en `PosCDG`; `StopPosicion` y el flag `StopPosiocion`; `TurnoService.AbrirTurno(turno, out id, turnoLibre)`; `ValidarIslero`; `PollPeticionTurno`; `ObtenerUltimoTurnoAbiertoByIdIslero`; `ActualizarMacTerminalTurno`; `AsyncAbrirTurnoSistemasWeb`; `TurnoModel.MacTerminal`; el nivel de precios "Autoservicio" y `ObtenerPreciosbyIdNivel`.

### Por comando

| Cmd | Qué hay que portar de NSX2 | Qué hay en Prime | Falta / decide | Riesgo |
|---|---|---|---|---|
| **E** | `case "E"`: estado más dinero, volumen y grado en tiempo real cuando surte, lista o autorizada | Existen `GetEstado` y `RealTime`. **Falta `GetGradoPreset`** (no está en `IPosicion` ni en `PosCDG` de Prime) | Agregar el `case` y `GetGradoPreset`; ver sección 15 | Bajo a medio |
| **PAS** | `case "PAS"` (validaciones de límite por dinero y volumen, estado de la posición, mensaje de preset activo) y `AutorizarAutoservicio` (crea la programación tipo Autoservicio con nivel "Autoservicio", turno desde el campo 11, `MacTerminal`, `TelefonoCliente`, corte en curso, la programa y notifica) | `ProgramarAutoServicio`, el flujo `ListoAutoServicio` y los datos de la programación existen. Falta `AutorizarAutoservicio` y `ObtenerPreciobyIdNivelyProducto` (en Prime hay `ObtenerPreciosbyIdNivel`) | Quitar `ValidarCorteBloqueante` (fuera de alcance). Columnas `MacTerminal`/`TelefonoCliente`/`IdIsleroAux` de la BD (fase de BD) | Medio |
| **S** | `case "S"` con la variante por turno (`NSXPlus` solo cancela un preset propio que no haya empezado a surtir) | `StopPosicion` y `StopPosiocion` existen; no hay `case "S"` | ¿Se incluye la variante por turno? El API actual envía `id\|pos\|S` sin turno | Bajo |
| **T1** | `AbrirTurnoPOS`: valida islero con clave cifrada, regla de un turno por isla, o por islero con `TurnoLibre`, y excepción de administrador; abre el turno con `MacTerminal`; avisa a sistemas web | Casi todo existe, incluido `AbrirTurno` de 3 parámetros. Falta leer `TurnoLibre` (no está en el `ConfiguracionEnum` de Prime) y `EsIsleroAdministrador` | **Decisión clave, ver abajo** | Medio |
| **T2** | `CerrarTurnoPOS` de 4 parámetros: resuelve el turno por las credenciales con `TurnoLibre`, valida posiciones de la isla en espera, cierra, imprime y guarda recibo de turno | Existe `CerrarTurnoPOS(idPosicion)` de un parámetro (usado por `AutoCT`). Faltan `GuardarReciboTurno`/`MixedReciboTurnoService`, `ValidarPresetsVivosCierre` y `AsyncHabilitarPreset`. Metas de turno: no aplica | Qué incluir del cierre (recibo guardado, presets vivos, metas) | Medio |
| **I1 / I2** | `SolicitarCopiaRecibo` y `SolicitarCopiaReciboIdVenta` (para Autoservicio usa `ImprimirEfectivo(idPosicion, idVenta)`) | En Prime la copia sale por la HMI (`PeticionCopiaVenta`, `gImprimirEfectivo`); no hay funciones por `idVenta` | **¿Dónde imprime el recibo del autoservicio?** | Alto |

### Decisión clave: turno libre
Con la regla de Prime "un turno abierto por isla", si el usuario de autoservicio tiene el turno abierto, **el islero no podría abrir el suyo** en esa isla (T1 respondería "La isla ya tiene un turno abierto"). Para el modo híbrido hay que usar la regla de `TurnoLibre` de NSX2 (un turno por islero) o la excepción de administrador. Eso implica agregar `TurnoLibre` a la config de Prime y su lectura en `LazoComunicacion`, y revisar los otros puntos del poll que dependen de "un turno por isla" (en NSX2 son líneas 2131 y 2174 de `LazoComunicacion`).

### Pregunta abierta: impresión
Hoy la HMI imprime (el MUX tiene impresora). Al quitarla, el recibo de la venta de autoservicio tiene que salir por otra vía. NSX2 usa `ImprimirEfectivo`, que escribe en `dbo.ImpresionPosicion` para una impresora de red. Hay que saber si el autoservicio tendrá impresora de red o térmica en la pantalla.

### Orden de trabajo propuesto (cada paso con tu OK)
1. `E` (sin dependencias).
2. `T1`/`T2` más `TurnoLibre`.
3. `PAS` con `AutorizarAutoservicio`.
4. `S`.
5. `I1`/`I2`, cuando se defina la impresión.
6. Revisar `ServidorPOS` de Prime para que enrute y responda igual (hoy tiene la validación de MAC comentada y el reparto de Puntos Colombia también).
7. BD (al final), Flutter y admin.

## 15. PosCDG: compatibilidad Prime y NSX2 (pendiente, se revisa a su tiempo)

Decisión: `PosCDG` de Prime debe quedar **compatible con ambos protocolos**. No se trabaja ahora; esto es lo encontrado en la comparación (`PosCDG.cs`, `IPosicion.cs`) para retomarlo.

**El mismo byte de estado significa cosas distintas:**
| Byte | Prime | NSX2 |
|---|---|---|
| `0x20` | `DatosFE` | `EsperandoID` |
| `0x21` | `ValidarClienteFE` | `IdClienteLeido` |
| `0x22` | `ListoClienteCemex` | `Autorizado` |
| `0x23` | `EstadoTurno` | `Stop` |

**Solo en NSX2:** lectura en vivo mientras surte (`gsSurtiendo`: dinero, volumen y grado) y `GetGradoPreset`; estados `gsListo` y `gsAutorizado`; trama `0xD3` (identificador de cliente leído) y subtramas `0xA1`; verificación de checksum y un segundo envío del preset con lectura de totales (`CapturarCapturarTotalesPreset`); `EnviarComandoPOS`, `EnviarMUXConfiguracion` (tabla `MuxConfiguracion`) y `SerialRecibido`; tipos de MUX Gilbarco, Zcheng, Wayne y "MUXNSX2LEOS"; el preset usa `ValorProgramado = -1` para full y `0` para no programar, y aritmética con `decimal`.

**Solo en Prime:** `MomentoCorte`/`FinCorte`, datos de factura electrónica desde la HMI (`0xC8`/`0xC9`), cliente Cemex (`0xCA`), datos de turno (`0xCB`), documento y tipo de documento, y MUX tipo Stone o Dwin.

**Lo que habrá que decidir cuando toque:** cómo elegir el protocolo por posición (por ejemplo, según la versión que responde el MUX o por config) y cuáles estados y tramas se manejan en cada modo. La config de MUX nueva y `GetGradoPreset` entran con `E`/`PAS`.

## 16. Fin de venta de autoservicio (primer hallazgo, falta cerrar)

Pedido: validar que, con `PAS`, el fin de venta quede bien. Lo visto hasta ahora en `ClientePosicion`:
- **Ya existe en Prime:** la lectura de formas de pago de autoservicio (`ObtenerFormasPagoAutoServicio`) y su amarre a la programación (`InsertarIdProgramacionFormaPagoAutoServicio`).
- **Hay tratamiento de `Autoservicio` en NSX2 que Prime no tiene:**
  - Armado del recibo de la venta local al terminar: el tipo Autoservicio entra en `ImprimirVenta` de NSX2 (la llamada registra "Arma Recibo"). **Corrección (2026-10-15):** no se comprobó que eso imprima papel al terminar la venta; esa parte era una deducción mía.
  - Copia de recibo permitida para Autoservicio.
  - Factura electrónica automática para Autoservicio (fase 2).
- **En la programación,** NSX2 y Prime tratan distinto el precio y la fecha inicial de una programación Autoservicio (Prime conserva `FechaInicial` y respeta el `IdPrecioProducto` que trae, para el modelo de reporte posterior de los `Auto*`). Con `PAS` hay que confirmar cuál comportamiento se quiere.
- **Pendiente:** recorrer el cierre completo (reporte de venta → inserción de la venta → pagos → impresión) con una venta `PAS` en Prime.

## 17. Comando `E` en Prime: hecho (2026-10-15)

**Cambios en `NSX-Prime\Software\Codigo NSX Prime`** (compila `Estacion.Poll` sin errores; solo advertencias que ya existían):
- `Estacion.Protocolos/IPosicion.cs`: nuevo `GetGradoPreset(int idPosicion)`.
- `Estacion.Protocolos/ProtocoloCDG/PosEmr3.cs`: `GetGradoPreset` devuelve 0.
- `Estacion.Protocolos/ProtocoloCDG/PosCDG.cs`:
  - `GetGradoPreset`; `Programar` guarda el grado programado (`grado + 1`) y se limpia en estado `Listo`.
  - **Tiempo real opcional en Surtiendo**: tras los 9 bytes básicos de la trama `0xA1` con estado `0x01`, se sondea un byte más con espera corta (60, unos 20 ms en serial). Si llegan los 26 bytes se llena dinero, volumen y grado con `gsSurtiendo`; si no llega, se cierra la trama y el tiempo real queda en 0. El resultado se recuerda (`_realTimeSoportado`) para no sondear en cada consulta, se reintenta cada 100 consultas, y se olvida si llega una trama que no empieza por `0xBC`.
  - Antes `gsSurtiendo` existía pero **nunca se llamaba**: el tiempo real no se llenaba en Prime.
- `Estacion.Pool/LazoComunicacion.cs`: `case "E"` en `ComandoPOS`. Responde `Estado|dinero|volumen|grado|gradoPreset` en Surtiendo y Reporte, `Estado|0|0|grado|gradoPreset` en Listo y Autorizado, y `Estado|0|0|0` en los demás. Mismo formato que NSX2.

**Decisión de diseño:** el tiempo real **no** se condiciona a la bandera `AutoServicio` por posición. En Prime esa bandera deja la posición fija en `Espera` y **no consulta el MUX** (es el modelo de reporte posterior de los `Auto*`), así que no sirve para el modelo `PAS`. Hace falta otra forma de marcar las posiciones `PAS`; candidata: que su dispensador tenga un `Autoservice.Dispositivo` activo.

**Pendiente de `E` (para la compatibilidad de PosCDG, sección 15):**
- La trama de estado `Listo` del firmware de NSX2 mide 10 bytes y trae el grado; Prime lee 9. Con ese firmware, `Listo` y `Autorizado` no darán el grado correcto hasta cubrir la compatibilidad.
- No hay prueba contra un MUX real: solo compila. Falta probar con un equipo con y sin tiempo real.

**Corrección:** `_turnoLibre` ya existe en `LazoComunicacion` de Prime, pero queda siempre en `false` (no se carga de la config; `ConfiguracionEnum` no tiene `TurnoLibre`).

## 18. Turnos del autoservicio en Prime: propuesta (2026-10-15, pendiente de OK)

**Regla dicha:** en Prime la responsabilidad es siempre por isla; **la única excepción es el autoservicio, y la marca el modo híbrido** (`Autoservice.Dispositivo`). Todo lo demás queda como está.

**Lo encontrado en el código de Prime**
- `TurnoService.ObtenerTurnoAbiertoByIdIsla` usa `GetSingle`: con **dos turnos abiertos en la misma isla lanza excepción** en sus ~20 puntos de uso (`LazoComunicacion`, `ClientePosicion`, impresión de venta, Satélite, etc.). NSX2 ya lo cambió a `GetLast`.
- La venta toma su turno de **`programacionVigente.IdTurno`** (`ClientePosicion`, fin de venta), no de la isla. Solo la ruta Tankio busca el último turno de la isla. Es decir, si `PAS` manda el turno en la programación, la venta queda a nombre de ese turno aunque haya dos abiertos.
- `TurnoService.AbrirTurno(turno, out id, turnoLibre)` ya existe en Prime. Falta quién decide `turnoLibre`: hoy `_turnoLibre` queda siempre en `false`.

**Propuesta ("turno libre acotado")**
1. **Isla normal o autoservicio puro:** igual que hoy, un turno por isla.
2. **Dispositivo híbrido:** `T1` usa la regla de turno libre solo para esa isla. Se permite un turno por islero, de modo que el del usuario de autoservicio y el del islero convivan. El dispositivo se identifica por la MAC del comando (`comandoArray[0]`) contra `Autoservice.Dispositivo.ModoHibrido`.
3. **Responsabilidad de cada venta:** `PAS` manda el turno en el campo 11. Si hay un islero logueado en la pantalla híbrida, va su turno; si no, el del usuario de autoservicio. `AutorizarAutoservicio` lo deja en `programacion.IdTurno` y el fin de venta ya lo respeta.
4. **Cierre (`T2`):** en dispositivo híbrido se resuelve por las credenciales (el turno de ese islero); en los demás, por isla como hoy. La validación de "todas las posiciones de la isla en espera" no puede bloquear al islero por la venta de un cliente en curso: en híbrido debe revisar solo los presets del turno que se cierra (en NSX2 es `ValidarPresetsVivosCierre`, falta en Prime).
5. **Cambio global necesario:** `ObtenerTurnoAbiertoByIdIsla` pasa de `GetSingle` a `GetLast` (como NSX2). Con un turno por isla devuelve lo mismo que antes; solo cambia cuando hay dos.
6. **Impresión y copias** que hoy buscan el turno de la isla (`ImpresionVenta`, copia de recibo) tomarían el último turno abierto; en híbrido hay que pasarles el turno de la venta.

**Supuestos a confirmar:** las posiciones híbridas están en una isla propia (solo autoservicio); el usuario de autoservicio es un islero distinto de los vendedores, con turnos programados que abre el servicio.

## 19. PosCDG: cómo distinguir los dos protocolos (idea para cuando toque)

Respuesta a "¿se pueden cruzar las tramas o la longitud lo cubre?":
- El tipo de trama (byte 6) **no se cruza**. El conflicto es solo en el byte de estado (byte 7) de la trama `0xA1`: `0x20` a `0x23` significan cosas distintas en cada firmware.
- La longitud sí ayuda para algunos estados: `Listo` mide 9 bytes en Prime y 10 en NSX2 (con grado); `Autorizado` mide 9 o 10; `Surtiendo` mide 9 o 26. Se puede sondear el byte extra con espera corta, igual que se hizo con el tiempo real.
- La longitud **no resuelve** `0x20` a `0x23`. Para eso, la forma limpia es preguntar la versión del MUX una vez por posición (`VersionMux`): Prime responde `S` (Stone) o `D` (Dwin); NSX2 responde `G`, `Z`, `W` o `L`. Con eso se elige el mapa de estados.

## 20. Ajuste de la propuesta de turnos (2026-10-15)

Respuestas del dueño del proyecto a la sección 18:
- **El vendedor vende por `P1`**, no por `PAS`. `PAS` queda solo para presets del autoservicio (nivel de precios "Autoservicio"); `P1` usa el precio normal de la posición. Así se separan los precios.
- **`P1` ya existe en Prime** y recibe el turno en el campo 11: valida con `ObtenerTurnoById` que el turno esté abierto y sea de la misma isla (es la ruta que hoy usa NSXPlus). Con `0` (islero auxiliar) busca el turno por isla.
- **`T1` solo llega por el comando POS**, con las credenciales del vendedor o del usuario de autoservicio. Los demás vendedores de la estación siguen entrando por PosCDG (HMI) como hoy. `T2` cierra según las credenciales que lleguen.
- **El equipo híbrido va en una isla aparte.** Un proceso automático abre y cierra los turnos del usuario de autoservicio.

**Consecuencias para el diseño**
- Como `T1`/`T2` por comando POS solo vienen de dispositivos de autoservicio, la regla de "un turno por islero" se aplica siempre a esa vía, sin consultar el modo híbrido. El flag híbrido define solo qué ve la pantalla (si deja entrar al vendedor). Las islas normales no cambian, porque entran por PosCDG.
- `ObtenerTurnoAbiertoByIdIsla` (`GetSingle` a `GetLast`) sigue siendo necesario como red de seguridad: con el turno del usuario de autoservicio y el del vendedor abiertos en la misma isla, `GetSingle` lanza excepción en los puntos que buscan "el" turno de la isla (`P1` con `0`, impresión, copia de recibo, Satélite). `P1` con turno explícito y `PAS` no dependen de eso.
- **No hace falta portar `P1`**; hace falta que el vendedor pueda llegar a él con el turno de `T1`.

**Orden ajustado**
1. Detectar el firmware del MUX por posición (para los estados de PosCDG).
2. `T1`/`T2` por comando POS con turno libre.
3. `GetLast` como red de seguridad.
4. `PAS` con `AutorizarAutoservicio`.
5. `S`, y luego `I1`/`I2`.

## 21. Detección del firmware del MUX: hecho (2026-10-15)

**Cuándo se pregunta:** no al arrancar, sino **después de que la posición responde estado**, y solo si está en `Espera`. Así se sabe que el MUX está vivo y no se gasta un timeout a ciegas ni se interrumpe una venta. Hasta 3 intentos por posición; si no responde, queda sin determinar y el comportamiento es el de hoy.

**Cambios en `Estacion.Protocolos/ProtocoloCDG/PosCDG.cs`** (Prime; compila `Estacion.Poll` sin errores):
- `VersionMux` ahora reconoce `G` Gilbarco, `Z` Zcheng, `W` Wayne y `L` MUXNSX2LEOS (firmware NSX2), además de `S` Stone y `D` Dwin (HMI de Prime). Guarda la letra en `_firmwareMux`.
- `VersionMux` ahora sale en el **primer byte que no llega**. Antes seguía y sumaba el último byte leído como si fuera respuesta (solo salía si fallaba el primero).
- `DetectarFirmware()` se llama al final de la lectura de estado y escribe en el log, por ejemplo: `Posicion 3 firmware MUX L -> protocolo NSX2`.
- `GetFirmwareMux()` expone la letra (aún no está en `IPosicion`).

**Aún no cambia ningún comportamiento:** solo registra. Los estados `0x20` a `0x23` y las tramas de `Listo` y `Autorizado` se adaptarán sobre esta detección, en la fase de compatibilidad de PosCDG (sección 15).

**Pendiente de probar con un MUX real** de cada tipo para confirmar la letra que devuelve y que la trama de versión mide 13 bytes en ambos firmwares.

## 22. Plan de `T1` / `T2` en Prime (pendiente de OK, 2026-10-15)

Todo en `Estacion.Pool/LazoComunicacion.cs`: dos `case` nuevos en `ComandoPOS` y tres métodos privados. Se reutiliza lo que ya existe en Prime: `TurnoIsleroService.ValidarIslero`, `TurnoService.AbrirTurno(turno, out id, turnoLibre)`, `ObtenerUltimoTurnoAbiertoByIdIslero`, `MixedSesionNSXPlusService.ActualizarMacTerminalTurno`, `AsyncAbrirTurnoSistemasWeb`/`AsyncCerrarTurnoSistemasWeb`, `ImpresionTurno` e `ImpresionGeneral`.

**`T1` (`mac|pos|T1|documento|password`)**
1. Valida el islero con la clave cifrada. Si falla: `E|0|Usuario o Password incorrecto`.
2. Abre el turno con turno libre siempre (un turno por islero en esa isla), guardando la MAC. Si el islero ya tiene turno abierto responde igual `T1|1|Turno abierto`, sin duplicar.
3. Avisa a los sistemas web como hoy. **No** envía nada a la HMI (`RespuestaTurno`), porque esa isla no tiene HMI.
4. Sin la excepción de administrador de NSX2: `IsleroModel` de Prime no tiene rol y no hace falta con turno libre.

**`T2` (`mac|pos|T2|documento|password`)** (sobrecarga de 4 parámetros; `CerrarTurnoPOS(idPosicion)` de `AutoCT` queda intacto)
1. Valida el islero y busca **su** turno abierto (no el de la isla). Sin turno: `E|0|El usuario no tiene un turno abierto`.
2. Actualiza la MAC del turno.
3. Valida solo los presets vivos **de ese turno** (portar `ValidarPresetsVivosCierre` de NSX2). No usa `PollPeticionTurno` de Prime, que bloquea por cualquier posición de la isla y escribe mensajes pensados para la HMI.
4. Cierra, arma e imprime el recibo del turno por la impresora de la posición, avisa a los sistemas web y responde `T2|1|Turno cerrado`.

**Fuera por ahora (a confirmar):** guardar el recibo de turno por id (`GuardarReciboTurno`, tabla `ImpresionTurno`, que no existe en esta BD), metas de turno, `AsyncHabilitarPreset` y el corte bloqueante.

## 23. `T1` / `T2` en Prime: hecho (2026-10-15)

**Cambios en `NSX-Prime\Software\Codigo NSX Prime`** (compila `Estacion.Poll` y `Estacion.Core` sin errores):
- `Estacion.Pool/LazoComunicacion.cs`:
  - `case "T1"` y `case "T2"` en `ComandoPOS` (si el comando trae menos de 5 campos responde `E|0|Comando de turno incompleto`). No se registra la clave en el log; NSX2 sí guarda el comando completo.
  - `AbrirTurnoPOS(idPosicion, usuario, password, mac)`: valida el islero, abre con turno libre (un turno por islero) y guarda la MAC. Si el islero ya tenía turno abierto responde `T1|1|Turno abierto` sin duplicar ni volver a avisar a los sistemas web.
  - `CerrarTurnoPOS(idPosicion, usuario, password, mac)`: sobrecarga de 4 parámetros; el `CerrarTurnoPOS(idPosicion)` de `AutoCT` no se tocó. Cierra el turno del islero de las credenciales, actualiza la MAC, imprime el recibo por la posición y lo guarda. Si imprimir o guardar el recibo falla, el turno queda cerrado y solo se registra el error.
  - `ValidarPresetsVivosCierre(turno)`: bloquea el cierre solo por presets activos **de ese turno**.
- `Estacion.Core/MixedServices/MixedReciboTurnoService.cs` (nuevo, agregado al `.csproj`): solo `GuardarReciboTurno`; la consulta y reimpresión del recibo siguen siendo de NSX2.

**Diferencias con NSX2:** sin excepción de administrador (no hay rol en `IsleroModel` de Prime), sin metas de turno, sin `AsyncHabilitarPreset`, sin corte bloqueante, y la impresión sale por la posición que envió el comando (NSX2 usa la de la última venta del turno).

**Para que guarde el recibo falta, en la fase de BD:** la tabla `dbo.ImpresionTurno` con `Fk_IdTurno`, `Impresion` y `FechaImpresion` (script 14 más los de `NSX2\Software\Scripts ReciboTurno BD`). Sin ella, `T2` cierra igual y deja el error en el log.

**Sin probar:** solo compila. Falta probar `T1`/`T2` contra Prime en una BD con un islero de prueba.

## 24. Pendiente grande: corte bloqueante

Se deja fuera del autoservicio de Prime por decisión del dueño del proyecto. Es un pendiente grande aparte: en NSX2 vive en `ValidarCorteBloqueante` (usado por `PAS`, `P1` y otros comandos), en `Turnos.CorteTurnoPendiente` y en la config `CorteBloqueante`. Prime solo tiene el campo `_corteBloqueante` sin uso.

## 25. Scripts de BD aplicados a la BD local (2026-10-15)

Carpeta: `Autoservicio\Scripts BD Prime\` (`LEEME.md` explica cada uno). Se aplicaron a `EstacionNSX` en orden y **se repitieron una segunda vez sin cambios**, y se comparó el esquema exportado antes y después: solo hay objetos nuevos y los dos triggers reescritos.

- **Respaldo previo:** `COPY_ONLY` en `C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\Backup\EstacionNSX_antes_autoservicio_20261015.bak` (verificado con `RESTORE VERIFYONLY`; sin compresión porque es Express).
- **Se crearon:** el esquema `Autoservice` (7 tablas), `dbo.Bandera`, `FormaPago.DetalleTransaccion`, `dbo.ImpresionTurno`, las columnas `MacTerminal`/`TelefonoCliente`/`IdIsleroAux` (programación e histórico) y `Autoservice.Dispositivo.ModoHibrido`; se sembró `Autoservice.Configuracion` (Bandera, Sistema=NSX, MaxVueltos=0) y los 4 estados de vueltos.
- **Prueba de triggers:** dentro de una transacción revertida, la fila nueva y el UPDATE de las tres columnas llegaron al histórico, y después del rollback no quedó nada (quedó solo un salto en el contador de identidad).
- **Hallazgo:** el EDMX de Prime mapea `MacTerminal` solo en `Turno`; `TelefonoCliente` e `IdIsleroAux` (y `MacTerminal` en la programación) no están mapeados. Se resuelve en `PAS`.
- **Aviso:** los archivos de esta BD (`.mdf`/`.ldf`) están en `D:\AUTOATENDIDO\Petromil-NSX\YDRAY-copibd2\copibd\`. El cambio fue solo en el esquema de esa BD (agregados), no en el código de Petromil.

## 26. Revisión de los scripts de BD: decisión (2026-10-15)

Tras revisar la lista de columnas, el dueño del proyecto decidió:
- **Se queda:** el esquema `Autoservice` (con `dbo.Bandera` y `FormaPago.DetalleTransaccion`), `ModoHibrido` en `Autoservice.Dispositivo` y `dbo.ImpresionTurno` (recibo de turno).
- **Se descarta:** `MacTerminal`, `TelefonoCliente` e `IdIsleroAux` en la programación y su histórico, y la reescritura de los dos triggers.

**Revertido en `EstacionNSX`:** las seis columnas se quitaron (estaban vacías) y los triggers volvieron a su definición original. Se verificó comparando el texto normalizado de ambos contra el original (idéntico; solo cambia que la definición guardada dice `ALTER` y no conserva el comentario de cabecera). El esquema exportado después contiene solo lo que se quedó. El respaldo previo sigue disponible.

**Consecuencias para `PAS`:** `AutorizarAutoservicio` en Prime **no escribirá** `MacTerminal`, `TelefonoCliente` ni `IdIsleroAux`, así que desaparece la tarea de mapearlas en el EDMX. La sección 22 y el `LEEME.md` quedan ajustados. La identificación del dispositivo en la venta se apoya en el turno (`IdTurno` en la programación) y en `Turnos.Turno.MacTerminal`, que ya existe.

## 27. Plan de `PAS` en Prime (pendiente de OK, 2026-10-15)

**Decisiones previas:** el vendedor vende por `P1`, `PAS` es solo del autoservicio; `PAS` no escribe `MacTerminal`/`TelefonoCliente`/`IdIsleroAux` y no se tocan los modelos; sin corte bloqueante; `GetSingle` a `GetLast` queda pendiente.

**Cómo funciona `PAS` (verificado en NSX2 y en Prime)**
1. `case "PAS"` valida límites del preset y el estado de la posición, y llama a `AutorizarAutoservicio`.
2. `AutorizarAutoservicio` inserta la programación (tipo Autoservicio, nivel "Autoservicio", precio de ese nivel para el producto, turno, corte en curso), la deja en la cola `_posicionProgramacionAutoServicio` y avisa a la pantalla de escritorio por `_programacionEventHandler`.
3. El poll (`ProgramarAutoServicio(posicion)`, que Prime ya tiene) llama a `Programar` hacia el MUX por PosCDG, pone `ProgramacionPendiente = false` y actualiza dinero y volumen iniciales.
4. En el fin de venta, la venta toma su turno de `programacion.IdTurno` y el tipo de la programación; las formas de pago que registró el API en `FormaPago.DetalleFormaPagoAutoServicio` se convierten en pagos de la venta (`InsertarFormasPagoAutoServicio`), **solo si la config global `AutoServicio` vale `1`**.

**Cambios propuestos (todo en Prime)**
- `Estacion.Pool/LazoComunicacion.cs`: `case "PAS"` y `AutorizarAutoservicio`. Respecto a NSX2: sin `ValidarCorteBloqueante`; estados permitidos `Espera` y `Listo` (los de `EsperandoID`/`IdClienteLeido` son del firmware NSX2 y entran con la compatibilidad); la espera de `ProgramacionPendiente` lleva una pausa corta (NSX2 la hace en un bucle sin pausa); si falta el precio de nivel Autoservicio para el producto responde un error claro en lugar de fallar con una excepción.
- `Estacion.Core/MixedServices/MixedPrecioProductoService.cs`: `ObtenerPreciobyIdNivelyProducto` (solo precios activos), portado de NSX2.
- `Estacion.Clientes/ClientePosicion.cs`, `ImprimirVenta`: agregar `Autoservicio` a las ventas que se imprimen al terminar, como en NSX2. **A decidir** (ver abajo).

**Hallazgos de la validación del fin de venta**
- Ya funciona en Prime: turno de la venta desde la programación, tipo de transacción y conversión de formas de pago.
- Falta en Prime respecto a NSX2: el tipo Autoservicio en `ImprimirVenta` (arma el recibo al terminar; no se verificó que imprima papel) y la copia de recibo para ese tipo (`I1`/`I2`, que vienen después).
- La config `AutoServicio` de `EstacionNSX` vale `0` y dos posiciones tienen `DispensadorPosicion.Autoservicio = 1`. En Prime esa marca por posición **deja de consultar el MUX en esa posición** (modelo de reporte posterior), así que las posiciones de `PAS` deben tener `Autoservicio = 0` y la config global `AutoServicio = 1` para convertir los pagos.

**A decidir antes de aplicar**
1. Turno obligatorio: si el campo 11 no trae un turno abierto de esa isla, `PAS` rechaza con un mensaje claro (recomendado; una venta sin turno no entra en ningún cierre). NSX2 la deja pasar con turno nulo.
2. Impresión automática del recibo al terminar la venta de autoservicio, o solo cuando la pantalla la pida con `I2`.

## 28. `PAS` en Prime: hecho (2026-10-15)

**Decisiones:** turno obligatorio (se rechaza si no viene uno abierto de la isla); el recibo sale solo cuando se pida (`I2`), y la factura electrónica la hace un servicio aparte, así que **no se tocó `ImprimirVenta`**.

**Cambios en `NSX-Prime\Software\Codigo NSX Prime`** (compilan `Estacion.Core` y `Estacion.Poll` sin errores):
- `Estacion.Pool/LazoComunicacion.cs`:
  - `case "PAS"` y `PresetAutoservicio(comandoArray)`. Formato: `id|pos|PAS|tipo|manguera|valor|placa|km|||| idTurno` (12 campos mínimo).
  - Validaciones, en este orden: comando completo; turno distinto de 0; turno abierto; turno de la isla de la posición; manguera existente; precio de nivel Autoservicio para el producto; límites de preset por volumen y dinero (con el precio de **autoservicio**, no el normal); estado de la posición `Espera` o `Listo`.
  - Con la posición `Autorizado` responde que ya hay un preset activo (NSX2 en ese caso podía detener el preset de otro turno; aquí no).
  - `AutorizarAutoservicio`: inserta la programación (tipo Autoservicio, nivel y precio de Autoservicio, `IdTurno` del campo 11, corte en curso), la encola para el poll y avisa a la pantalla de escritorio. No escribe `MacTerminal`, `TelefonoCliente` ni `IdIsleroAux`. Devuelve error real si no pudo insertar (NSX2 respondía éxito).
  - Espera hasta 8 s a que el poll programe el MUX, con pausa de 50 ms; a los 4 s vuelve a encolar **la misma** programación (NSX2 insertaba una segunda).
  - `ObtenerPrecioAutoservicio`: busca el nivel "Autoservicio" y el precio activo del producto.
- `Estacion.Core/MixedServices/MixedPrecioProductoService.cs`: `ObtenerPreciobyIdNivelyProducto` (solo precios activos), portado de NSX2.

**Respuestas:** `P1|pos|Surtiendo` si salió bien (igual que NSX2) o `E|0|mensaje`.

**Cambio posterior (revisión del 2026-10-15), distinto de NSX2:** si el MUX no recibe el preset, `PAS` ya **no** responde éxito. Cuando el poll saca la programación de la cola pero la bandera `ProgramacionPendiente` sigue arriba (falló el envío), o a los 8 s sin confirmación, `PAS` anula la programación (`ProgramacionAnulada`), la saca de la cola, baja la bandera y responde `E|0|El equipo no recibio el preset, intente de nuevo` (o `no confirmo`; en ese caso también pide el stop por si el MUX lo recibe tarde). Además, un segundo `PAS` mientras hay uno en cola responde `E|0|La posicion N tiene un preset en proceso`. Con una posición marcada `DispensadorPosicion.Autoservicio = 1` (que Prime no consulta), `PAS` ahora falla a los 8 s en vez de aparentar éxito.

**Requisitos de la estación para que funcione completo**
- Posiciones de `PAS` con `DispensadorPosicion.Autoservicio = 0` (con `1` Prime deja de consultar el MUX; hoy hay 2 posiciones en `1` en `EstacionNSX`).
- Config global `AutoServicio = 1` para que el fin de venta convierta los pagos del servicio en pagos de la venta (hoy vale `0`).
- Precio activo en el nivel "Autoservicio" para cada combustible. En `EstacionNSX` están los tres (Corriente 15690, Diésel 21390, Extra 21000). **Dato a revisar:** el Diésel de Autoservicio (21390) es muy distinto de su precio normal (11850).

**Sin probar:** solo compila. Falta una prueba con un MUX y la BD, y con el servicio real mandando `T1` y luego `PAS`.

## 29. Por qué `PAS` espera al poll, e impresora de 56 mm (2026-10-15, sin cambios de código)

### Por qué `PAS` espera al poll (igual que NSX2)
- Hay dos tipos de hilo. El **poll** es el único que habla con el MUX por el puerto (serie o socket); si dos hilos escribieran a la vez las tramas se mezclarían. Los comandos del API llegan a `ServidorPOS`, que los atiende en otros hilos (`Task.Run`).
- Por eso `PAS` no puede programar el MUX directamente: inserta la programación, la deja en una cola (`_posicionProgramacionAutoServicio`) y el poll la toma en su siguiente vuelta (al final de `Poll(posicion)` llama `ProgramarAutoServicio(posicion)`), envía `Programar` al MUX y baja la bandera `ProgramacionPendiente`.
- `PAS` espera esa bandera para responder solo cuando el MUX ya recibió el preset. NSX2 lo hace igual, con un bucle sin pausa y un reintento a los 4 s que insertaba una segunda programación. La demora es una vuelta del poll; depende del número de posiciones y de `VelocidadPool`. **Sin medir todavía.**

### Impresora de 56 mm
Lo que tiene NSX2 y no Prime:
- **BD:** `TipoComunicacion` 4 `Impresora56` y la config `PollImpresora` (id 68), del script 125. Ninguna existe hoy en `EstacionNSX`. Yo había quitado `Impresora56` del script 01; hay que ponerla de vuelta.
- **Código** (`Estacion.Impresion/ModeloImpresion.cs`; Prime tiene 675 líneas, NSX2 895):
  - NSX2 detecta el 56 mm con `LazoComunicacion.IdTipoComunicacion == 4` y usa la fuente B (`ESC M 1`) para que el recibo quepa.
  - Su rutina de texto inicializa la impresora (relleno de 2048 ceros y `ESC @`, para sacarla del modo imagen), usa CP437 con `ESC R 13` (el `$` y las tildes salen bien) y pone tiempo límite al socket.
  - La de Prime es la versión simple: sin inicialización, sin tiempo límite, bytes en UTF-8.
  - NSX2 también trae impresión de imagen, QR y firma por socket, que Prime no tiene.
- **Riesgo si se copia entero:** la rutina de NSX2 cambia la codificación para todas las impresoras de red. En Prime podría alterar las de 80 mm que hoy imprimen bien.

**Propuesta:** BD (tipo 4 y, si se quiere, `PollImpresora`) y, en código, usar la rutina de NSX2 solo para lazos de tipo 4; las demás impresoras quedan como están. Si el autoservicio también necesita logo en imagen o QR, eso es otro paso.

## 30. Impresora de 56 mm, QR y bloqueo al imprimir en Prime: hecho (2026-10-15)

**Contexto:** el log de una estación mostró `Fallo al imprimir WIFI 192.168.40.244:9100 ... la parte conectada no respondió ...` tres veces seguidas, y en otra estación el polling se quedó quieto al fallar un socket de impresión y hubo que reiniciar.

**Hallazgos del código de Prime**
- `ImprimirSocket` lanza un `Task.Run` por cada impresión y `socket.Connect` no tiene tiempo límite (espera unos 20 s). Si la impresora no responde, cada trabajo deja un hilo del pool bloqueado.
- El socket no se cierra si falla (no hay `using` ni `Close` en el `catch`): se acumulan conexiones.
- Todos los hilos de fondo de NSX (poll, cola de impresión, servidor POS) viven en el mismo pool de hilos. No pude confirmar que esa sea la causa del bloqueo que viste; es la hipótesis más plausible y está corregida.
- En Prime las impresoras de 56 mm no se reconocían: la consulta solo trae lazos de tipo 2, y quien imprime solo pasa la IP (igual que en NSX2).

**Cambios en `NSX-Prime\Software\Codigo NSX Prime`** (compilan `Estacion.Core`, `Estacion.Impresion`, `Estacion.ImpresionPosicion` y `Estacion.Poll`):
- `Estacion.Core/MixedServices/MixedImpresionPosicionService.cs`: `ObtenerPosicionesImpresionWIFI` acepta lazos de tipo 2 y 4.
- `Estacion.Impresion/ModeloImpresion.cs`:
  - `EsImpresora56mm(lazo)`: tipo 4 directo o, si solo trae IP, busca el lazo por IP.
  - Texto: si es 56 mm usa la rutina de NSX2 (relleno de 2048 ceros y `ESC @`, CP437 con `ESC R 13`, fuente B `ESC M 1`); **las demás impresoras envían exactamente los mismos bytes de antes**.
  - QR nuevo `ImprimirSocketQR2(qr, lazo, ancho, alto)` con las dimensiones del bitmap; el QR de siempre conserva su cabecera.
  - Robustez en texto y QR: conexión con tiempo límite de 5 s, el socket siempre se cierra, un candado por IP para que dos envíos a la misma impresora no se mezclen, y si una impresora falló se omiten sus envíos durante 10 s (queda en el log) en vez de dejar un hilo esperando en cada uno.
- `Estacion.ImpresionPosicion/ImpresionPosicion.cs`: en las dos rutas de QR, si la impresora es de 56 mm regenera el QR a 352 puntos y usa `ImprimirSocketQR2`; si no, imprime como antes.

**Script de BD:** `Scripts BD Prime\05_Impresora56.sql` crea `TipoComunicacion` 4 `Impresora56`. **Escrito pero sin ejecutar** hasta que se revise.

**Limitaciones**
- No se portó el chequeo de conexión de impresoras de NSX2 (`PollImpresora`), ni la impresión de imagen o firma por socket.
- Una impresión que se omite o falla se pierde; no hay reintento ni cola.
- Sin probar con una impresora real: solo compila. Probar un recibo `I2`/turno y un QR en una de 56 mm, y apagar la impresora para ver que NSX sigue respondiendo.
- Si el bloqueo vuelve, se puede fijar el mínimo de hilos del pool al arrancar; queda como opción.
