# Cambios y pendientes — 9 de noviembre de 2026

Lo hecho en esta sesión y lo que queda abierto, para continuar sin depender de la conversación.
No lleva claves: las de `sa` del servidor 192.168.9.68 y del usuario Windows `tito` se dieron por el chat.

---

## 1. Servidor de pruebas 192.168.9.68 (Windows 11 Pro, SQL Server 2022 Express, nombre DESKTOP-H31DM3F)

### Hecho
- **Base de datos:** `EstacionNSX` reemplazada por el `.bak` de Prime 5.0.27 del instalador (`NSX V 5.0.27 26 AGO 26\Instalador NSX PR 5.0.27\EstacionNSX.bak`) y scripts de autoservicio 01 a 12 aplicados sin errores.
  - Respaldo de la base anterior (vacía, 0 ventas, colación `Modern_Spanish_CI_AS`): `EstacionNSX_antes_reemplazo_20261109.bak` en la carpeta de respaldos de SQL (`C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\Backup`).
  - Archivos de la base: `D:\Nueva autopista\EstacionNSXFactura.mdf` y `_log.ldf`.
  - Usuarios de la base recreados porque el `.bak` no los trae: `NSX` (db_owner), `mantenimiento` y `reportesnsx` (db_datareader). Sin esto el login `NSX` no podía abrir la base.
- **.NET 8 Hosting Bundle 8.0.33** instalado (descarga oficial, firma de Microsoft verificada). El instalador temporal se borró.
- **API** en `http://192.168.9.68:8061` (IIS, sitio `NSXAutoservicioAPI`, carpeta `D:\Insepet\NSXAutoservice\API`). Su `appsettings.json` apunta a la `EstacionNSX` local del servidor. Incluye las correcciones del día (coma decimal, saldo, caché de `IPNsxAPI`).
- **Página de configuración** en `http://192.168.9.68:8065` (sitio `NSXAutoserviceAdmin`, carpeta `D:\Insepet\NSXAutoservice\Admin`). Su `config.json` apunta a `http://192.168.9.68:8061/api`. El API tiene CORS abierto.
- Reglas de firewall para los puertos 8061 y 8065.
- **NSX instalado** con el `.msi` en `C:\Program Files\Sistemas Insepet\NSX` (hoy en 5.0.28 de prueba, ver sección 5).
- Acceso remoto usado: WinRM (usuario `tito`, administrador). En esta PC se agregó `192.168.9.68` a `TrustedHosts`.
- Convivencia: el servidor ya tenía 6 sitios IIS en los puertos 80 a 85; no se tocaron.

### Pendiente
- **La base no está en blanco:** trae 6 posiciones, 1.315 ventas, unas 200.000 filas en `dbo.Log`, 198.000 en `FElectronica.MensajesError`, 42.000 en `OperacionOnline`, 27.500 en `Adquiriente`. La `EstacionNSXLimpiaPrimeVer27.bak` (Base de Datos del repo) NO sirve para esto: es de 2018 (150 tablas, sin esquema Autoservice ni FElectronica). Opción recomendada: limpiar los datos de operación de la del instalador, dejando catálogos y configuración, con respaldo antes.
- **Abrir NSX en el servidor** (acceso directo del escritorio) y comprobar que arranca y conecta. Yo solo tengo sesión remota, sin pantalla.
- **Prime no corre en ese servidor todavía.** El API busca Prime en `127.0.0.1:8010` (config `IPNsxAPI`), por eso `ObtenerEstado` responde "Error Envio Comando". Al abrir NSX debería escuchar el 8010.
- Para que una Orange use este servidor: registrar su MAC en `Autoservice.Dispositivo` y poner su `API_NSX` en `http://192.168.9.68:8061/api`.
- **Seguridad:** `tito`/`123456` y la clave de `sa` son débiles; cambiarlas. Cerrar lo abierto por la prueba: carpeta compartida `SQLBackup` (en el servidor), WinRM y el `TrustedHosts` de esta PC.

---

## 2. Prime (código en `D:\TeamsInsepet\NSX-Prime\Software\Codigo NSX Prime`)

### Hecho (compilado y desplegado solo en `NSX\bin\Debug` local; respaldo en `_respaldo_pos_20261109_0824`)
- `Estacion.Sincronizacion.Poll\ModeloSincronizacionPoll.cs`: el comando `E` (estado) ya no espera el candado global (`lock thisLock`), que retenían turnos, presets y cortes mientras escribían a la BD. Búsqueda del modelo por posición con `ConcurrentDictionary`.
- `ProtocoloPOS\ServidorPOS.cs`: `Listen(1)` pasa a `Listen(200)`; si un comando falla responde `E|0|No se pudo procesar el comando` en vez de dejar al cliente esperando 5 s; el socket siempre se cierra. La consola quedó como estaba (los `Console.WriteLine` originales).
- `Estacion.Pool\LazoComunicacion.cs`: el `LogDebug("Respuesta NSX - POS ...")` ya no se escribe para el comando `E` (era un INSERT síncrono en `dbo.Log` por cada consulta).
- `Estacion.Protocolos\ProtocoloCDG\PosCDG.cs`: el grado en `Autorizado` se lee como en NSX2 (`respuesta[8] | 0x30`).
- Prueba contra el 8010 local, comparada con la anterior: 8 hilos sin pausa pasó de 424 a 2.357 consultas/s, 32 hilos de 42 a 766/s, 0 errores, y 0 filas nuevas en `dbo.Log` durante la prueba.

### Pendiente
- Copiar al **.80** (y a donde corra Prime en producción), con NSX cerrado y respaldo: `ProtocoloPOS.dll`, `Estacion.Sincronizacion.Poll.dll`, `Estacion.Poll.dll` y `Estacion.Protocolos.dll`.
- Revisar en el .80 por qué Prime anuló el preset del vendedor de las 09:25:37 (programación 5281, estado 3): consulta del log de Prime entre 09:25:30 y 09:25:50.

---

## 3. API (`D:\Autoservice\Repositorio\Autoservice\NSXAutorserviceAPI`)

### Hecho
- `NSXAutoservicioService.cs`: `ParseDecimal` cambia la coma por punto (Prime manda `4,942` y el API lo leía como `4942`); el saldo de cliente (4 lugares) usa el helper seguro.
- `ComunicacionNSX.cs`: `IPNsxAPI` y `Sistema` se leen de SQL una sola vez y quedan en memoria. Si cambian, reiniciar el sitio en IIS.
- Carpeta publicada: `NSXAutorserviceAPI\NSXAutoServiceAPI\bin\Release\net8.0\publish`.

### Pendiente
- Confirmar que el API del **.80:8061** ya tiene esta carpeta. Al copiar no pisar su `appsettings.json`.
- Que `CrearPresetVendedor` incluya en el error la respuesta de Prime y el estado final de la programación (hoy responde "No se pudo programar el preset" sin motivo).

---

## 4. Orange 192.168.110.67 y su repo (`D:\Git\AutoservicioNSX`, rama Camilo)

### Hecho
- Migración `007_pantalla_config_tiempo_real.sql` (tabla `pantalla_config`, por serial) aplicada. El mapeo de cada pantalla trae `realtime` (`enabled`, `intervalMs`, `style`). Filas cargadas para los seriales `6E311D2AC7DE`, `88003377D2BA`, `880033770652`, `88003377E8AF` y `1C54E60E4004`, todas con tiempo real activo a 500 ms.
- `service/src/repositories/system/repository.js`: el 404 de `synchronize-screen` ahora dice `(serial recibido: …)`.
- Imágenes `paso_*.png` subidas a `service/public/img`.
- **Consola `consola_autoservicio` encendida y habilitada al arranque.** Cerró el preset pegado (venta 5307). Al arrancar cierra y abre turnos del autoservicio en NSX por horario.
- **Hora corregida:** estaba 1 h 37 min atrasada y sin sincronizar; ahora toma la hora del router (`192.168.110.252`) vía `/etc/chrony/sources.d/insepet.sources`. Internet NTP está bloqueado en esa red.
- Respaldos en la Orange: `/root/respaldo_tiempo_real_20261109_0922`.
- Los consolas de la Orange corren el código nuevo de Andrés (Hospitality), idéntico al repo.

### Pendiente
- **Hospitality sin script de esquema:** el código usa `estacion.hospitality`, `transaccion_pago.recibo` y la tabla `aprobacion_pago`, pero no están en `consola/database/migrations`. Escribirlo como `008_hospitality.sql` idempotente.
- `getPendingSaleAuthorization` hace `INNER JOIN` con `terminal_posicion` activa: una posición sin terminal (hoy la 2 y la 4) nunca sincroniza sus ventas. Cambiar a `LEFT JOIN`.
- `reportStatusWhileSupplying` devuelve `true` y saca la autorización de la cola; Andrés ya encontró el error, confirmar su corrección.
- `consola/.env` está versionado con MAC e identificador de la .67 y claves.
- Resincronizar la Orange hace que la consola cierre y abra un turno nuevo en NSX cada vez.
- La Orange sincroniza el serial de cada tablet desde el `SerialPantalla` del .80 (`Autoservice.Recursos`); hoy: posición 1 = `1C54E60E4004`, posición 2 = `6E311D2AC7DE`.
- Copiar los `paso_*.png` a las otras Orange.

---

## 5. Instalador de NSX (`SetupNSX.msi`)

### Hallazgos
- El MSI entregado (5.0.27) ya reemplaza versiones anteriores: mismo `UpgradeCode` `{0B2D8AA0-4A92-458E-B3B3-A18992480EDB}`, `RemoveExistingProducts` incluido, y bloquea instalar una versión más vieja (probado: código 1603).
- **El proyecto `SetupNSX.vdproj` del repo está desactualizado:** `ProductVersion = 5.0.6` y `RemovePreviousVersions = FALSE`.
- **Fallo de fondo:** todos los programas tienen versión de archivo `1.0.0.0`; al actualizar, Windows Installer no reemplaza los que tienen la misma versión. Probado en 192.168.9.68: la actualización 5.0.27 → 5.0.28 cambió el número pero dejó `Estacion.Poll.dll`, `Estacion.Sincronizacion.Poll.dll` y `Estacion.Protocolos.dll` del 26 de agosto.
- **Solución probada:** `REINSTALLMODE=emus`, tanto en la línea de comandos como **dentro del propio MSI** (tabla `Property`). Con eso, un `msiexec /i SetupNSX.msi /qn` sin parámetros reemplazó los cuatro programas y conservó los cambios de `NSX.exe.config`.
- El MSI no toca la base de datos (se actualiza con el `.dacpac` o los scripts numerados) ni crea el usuario `NSX` dentro de ella.
- El proyecto de instalador toma `NSX.exe` de `..\NSX\obj\Debug\NSX.exe`: solo se puede generar en configuración Debug sin cambiar el `.vdproj`.
- **Hay que compilar la solución como `Debug|x86`, no `Debug|Any CPU`.** El `NSX.exe` del instalador 5.0.27 es de 32 bits obligatorio (`REQUIERE 32 bits`) porque depende de DLL de 32 bits (`vjslib.dll`, `vjslibcw.dll`, `WPFSparkClient.exe`, `Estacion.Usuarios.exe`). Compilado como "Any CPU" corre como proceso de 64 bits en Windows de 64 bits y se cierra al instante con `System.BadImageFormatException` al cargar Entity Framework (pasó en 192.168.9.68).
- Con el instalador x86 (`D:\BuildNSX\SetupNSX_5.0.28_x86.msi`, ya con `REINSTALLMODE=emus`), NSX arrancó en 192.168.9.68 lanzándolo dentro de la sesión de escritorio con una tarea programada (`New-ScheduledTaskPrincipal -LogonType Interactive`); desde WinRM directo no tiene escritorio. Lee y escribe `dbo.Log`; el puerto 8010 no escuchaba aún (probable pantalla de inicio de sesión pendiente).

### Hecho
- Script `Instalador\ParcharMsi.ps1` (junto a este documento): deja `REINSTALLMODE=emus` en un `.msi`; se puede correr varias veces.
- MSI de prueba 5.0.28 con la opción ya dentro: `D:\BuildNSX\SetupNSX_5.0.28_prueba_auto.msi` (Debug; no entregar a clientes).
- Copia de compilación: `D:\BuildNSX\root\NSX-Prime\Software\Codigo NSX Prime` (con la librería compartida `D:\BuildNSX\root\Librerias` a la altura que esperan los proyectos). La solución compila completa (50 proyectos).
- Se ejecutó `DisableOutOfProcBuild.exe` (clave `HKCU\...\17.0_bd8b9b94_Config\MSBuild\EnableOutOfProcBuild = 0`) para poder compilar instaladores desde la línea de comandos. Se deshace con `DisableOutOfProcBuild.exe undo`, ejecutándolo desde su carpeta.
- En el servidor de pruebas quedó NSX 5.0.28 con todos los archivos al día. Registros e instaladores en `D:\Insepet\Instaladores\`.

### Pendiente
1. En `SetupNSX.vdproj` del repo: subir `ProductVersion`, poner un `ProductCode` nuevo en cada versión, `RemovePreviousVersions = TRUE`, y mantener `UpgradeCode`.
2. Agregar al proyecto de instalador un evento posterior a la compilación que llame a `ParcharMsi.ps1`, por ejemplo:
   `powershell -NoProfile -ExecutionPolicy Bypass -File "<ruta>\ParcharMsi.ps1" -Msi "$(BuiltOuputPath)"`
   (la macro se escribe así en Visual Studio). Probarlo con una compilación completa.
3. Mejor a largo plazo: un archivo de versión compartido en todos los proyectos (`AssemblyVersion` y `AssemblyFileVersion`) que suba en cada release.
4. Decidir cómo se crea el usuario `NSX` en la base y cómo se aplican los scripts de base de datos al actualizar.
5. Probar el instalador contra una instalación de NSX en uso real (configuración distinta de la de fábrica).

---

## 6. App Flutter (`D:\Autoservicions2\gnesys_as`, sin git) y página de configuración

### Hecho hoy
- Escalado a pantalla grande de: venta del vendedor, "Listo para surtir", crédito, ventas del turno, pagos, agregar pago, surtiendo (cliente) y autorización pendiente. Reloj en dos líneas con fecha, avisos grandes (`showAppNotice`) y los avisos de abajo de las pantallas del cliente migrados a ese aviso.
- Instrucciones del cliente: un paso a la vez, con imágenes (`paso_motor`, `paso_tanque`, `paso_manija`, `paso_pistola`, `paso_gatillo`) tomadas de los recursos de la Orange.
- Listado de ventas del turno muestra dinero y galones reales, con consulta a NSX por venta.
- **Tiempo real:** franja inferior con valor, galones, PPU y un carrito que avanza hacia la bandera (`lib/presentation/widgets/realtime_strip.dart`), en las pantallas de surtiendo del vendedor y del cliente; se activa por pantalla desde la Orange. Si el surtidor no manda volumen, se calcula con dinero ÷ PPU.
- Hospitality: con la bandera activa no se muestra el modal de vueltos; se avisa que el valor se cobrará a la tarjeta.
- Serial de la tablet: siempre la MAC cableada (`eth*`); si no hay, la última guardada; si nunca hubo, la Wi-Fi. La configuración muestra las MAC de cada interfaz. El error de sincronizar ya muestra el mensaje real.

### Pendiente
- Interruptor "Tiempo real" e intervalo por pantalla en la página de configuración (hoy se cambia con SQL en `pantalla_config`).
- Escalar `configuration_screen` y `update_widget`. Borrar `sale_screen.dart` y `keypad_screen.dart` (sin uso).
- Pasar a un solo aviso los snackbars restantes de configuración.
- Reconocimiento facial / lector RFID del vendedor: ver `D:\TeamsInsepet\RETOS.md`.

---

## 7. Cómo retomar
1. Instalador: seguir en la sección 5 → pendientes 1 y 2.
2. Servidor 9.68: sección 1 → abrir NSX y limpiar la base.
3. Producción: copiar API y DLL de Prime al .80 (secciones 2 y 3).
4. Orange: escribir `008_hospitality.sql` y corregir el `JOIN` (sección 4).
