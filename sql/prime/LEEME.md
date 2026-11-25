# Scripts de BD para el autoservicio en NSX Prime

Todos son **idempotentes** (se pueden correr varias veces) y se ejecutan dentro de la BD de la estación, en orden:

| # | Archivo | Qué hace |
|---|---|---|
| 01 | `01_Esquema_Autoservice.sql` | Esquema `Autoservice` (Configuracion, Dispositivo, EstadoVueltos, Fidelidad, FormaPago, Recursos, Vueltos), `dbo.Bandera`, `FormaPago.DetalleTransaccion`, y los catálogos con ids de Prime (TipoTransaccion 20, Nivel "Autoservicio") si faltan |
| 02 | `02_ModoHibrido_Dispositivo.sql` | Columna `Autoservice.Dispositivo.ModoHibrido` (BIT, por defecto 0) |
| 04 | `04_ImpresionTurno.sql` | `dbo.ImpresionTurno` con `Fk_IdTurno`, `Impresion` y `FechaImpresion` (recibo de turno guardado por `T2`) |
| 05 | `05_Impresora56.sql` | `TipoComunicacion` 4 `Impresora56` (impresoras de red de 56 mm). Ejecutado sobre `EstacionNSX` el 2026-10-15 |
| 06 | `06_Turno_MacTerminal.sql` | `Turnos.Turno.MacTerminal` a `varchar(20)` (solo ensancha): con `nchar(10)` una MAC de 12 caracteres hace fallar `T1` (error 8152). Ejecutado sobre `EstacionNSX` el 2026-10-15 (era `nchar(10)`) |
| 07 | `07_FormaPagoVendedor.sql` | `Autoservice.FormaPagoVendedor`: formas de pago de NSX que el vendedor puede anclar a su venta (independiente de `Autoservice.FormaPago`, las casillas del cliente). Se llena con las formas activas de NSX, menos la redención de Commodo. Ejecutado sobre `EstacionNSX` el 2026-10-21 |
| 08 | `08_DispensadorPosicion_AutoServicio.sql` | Columna `dbo.DispensadorPosicion.AutoServicio` (BIT NULL) que mapea el EDMX de Prime; sin ella falla la lectura de posiciones. Aplicado el 2026-10-29 sobre la base nueva de 192.168.110.80 (5.0.27) |

| 09 | `09_Configuracion_IPNsxAPI.sql` | Configuración `IPNsxAPI` (ip y puerto del puerto de comandos de NSX Prime, separados por barra vertical) que lee el API; por defecto `127.0.0.1` y `8010`. Aplicado el 2026-10-29 sobre la base nueva de 192.168.110.80 |
| 10 | `10_PrecioAutoservicio_desde_Nivel1.sql` | Crea el precio del nivel `Autoservicio` igual al del `Nivel 1` para cada producto que tenga precio activo ahí y ninguno en `Autoservicio`; no pisa precios existentes. Los demás se crean a mano en NSX. Aplicado el 2026-10-29 sobre la base nueva de 192.168.110.80 |
| 11 | `11_FormasPago_Autoservicio_Default.sql` | Crea `Datafono`, `Nequi` y `QRVueltos` en `FormaPago.FormaPago` si faltan y las habilita en `Autoservice.FormaPago` (espacios fijos 1, 2 y 3); no pisa espacios existentes. Aplicado el 2026-10-29 sobre la base nueva de 192.168.110.80 |
| 12 | `12_VentaFidelizada_Fk_IdFidelidad.sql` | Columna `Fidelidad.VentaFidelizada.Fk_IdFidelidad` (INT NULL) que lee el API para saber el programa de fidelidad de la venta; sin ella fallaba el estado del preset. Aplicado el 2026-10-29 sobre 192.168.110.80 |
| 14 | `14_Dispositivo_Identificadores_TiempoReal.sql` | Columnas `IdentificadoresCliente`, `TiempoReal` e `IntervaloTiempoReal` en `Autoservice.Dispositivo` |

(La numeración salta el 03: ese script se descartó, ver abajo.)

```bash
sqlcmd -S <servidor> -d <BD> -U <usuario> -b -f 65001 -i 01_Esquema_Autoservice.sql
```

## Diferencias con `124. Modulo Autoservicio NSX2.sql`
- No inserta `TipoTransaccion` 22/23 (en Prime Tankio = 19, Autoservicio = 20).
- No inserta el nivel "Tankio". `TipoComunicacion` 4 "Impresora56" va aparte, en el 05.
- Los defaults tienen nombre fijo; todo lleva `IF NOT EXISTS`.

## Descartados (carpeta `Descartados`)
- `03_Programacion_Columnas_Triggers.sql`: agregaba `MacTerminal`, `TelefonoCliente` e `IdIsleroAux` a `DispensadorPosicionProgramacion` y su histórico y reescribía los triggers `InsertarProgramacion`/`ActualizarProgramacion`. **No se usa**, y por eso `PAS` en Prime no guardará esas columnas.
- `Revertir_03_Programacion.sql`: lo deshace (restaura los triggers originales y quita las columnas). Ya se ejecutó sobre `EstacionNSX`.

## Lo que NO incluyen (a propósito)
- `dbo.Terminal` (script 1 de NSX2): en Prime la validación de MAC de `ServidorPOS` está comentada.
- `dbo.MuxConfiguracion` (script 2): `EnviarMUXConfiguracion` no está portado.
- Config `TurnoLibre`: `T1`/`T2` usan turno libre siempre.
- Corte bloqueante (`Turnos.CorteTurnoPendiente`, config `CorteBloqueante`): pendiente grande.
- Datos de `Autoservice.FormaPago`, `Fidelidad`, `Recursos` y `dbo.Bandera`: se llenan desde el admin.
