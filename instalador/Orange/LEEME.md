# Orange: instalar y actualizar

## Publicar (en el PC de desarrollo, Git Bash)
`bash /d/Git/AutoservicioNSX/orange/actualizador/armar.sh "" "que cambio"`
Suba el contenido de `Instalador Autoservicio\Orange\AutoservicioNSX\` a `http://nsx2.insepet.com:82/AutoservicioNSX/`
(`instalar.sh`, `versions.json`, `web.config` y el `.run`).
Otra direccion: `URL_BASE=https://... bash armar.sh`.

## En la Orange (instalacion nueva o actualizacion)
`curl -fsSL http://nsx2.insepet.com:82/AutoservicioNSX/instalar.sh -o /tmp/instalar.sh && sudo bash /tmp/instalar.sh`
Opciones: `instalar.sh <version>` para una anterior; `--forzar` para reinstalar la misma.
Sin servidor: `sudo bash autoservicio-orange-<version>.run`, o soltarlo en `Node/actualizar/` (solo ya instalada).
Siempre queda un `..._OK.txt` o `..._ERROR.txt` (con descarga: en `/opt/nsx/descargas/`).

## Que hace
- Instala lo que falte: Node 20, PostgreSQL, librerias (necesita internet).
- Base: usuario `postgres`, clave `admin`, base `autoservicionsx`; no crea usuarios. Crea tablas y datos iniciales.
- Crea carpetas, `.env` y servicios `autoservicensx-{consola,server,terminal}` si faltan.
- Instalacion nueva: pide URL del API, MAC, `API_KEYS` e `IO_API_KEY` (o `orange.config`).
- Actualizacion: respeta `.env`, base y archivos de `server/public`; respalda y revierte el codigo si falla.
- La reversa no desinstala programas ni borra la base.
- No toca `pagina` ni `gestor_leds`. La liberacion de pagos del terminal sigue desactivada.
- A mano: asignar datafono e impresora a cada posicion (`terminal_posicion`, `impresora_posicion`).

## orange.config (opcional, junto a instalar.sh o al .run)
```
API_NSX=http://192.168.1.10:8070/api
# MAC=  IDENTIFIER=  API_KEYS=  IO_API_KEY=  DB_NAME=  BASE=/home/orangepi/Documents/Node
```

## Seguridad
- Solo se instalan paquetes firmados con `actualizador\llave\privada.pem`: respaldela y no la suba ni la envie.
- El `.run` no lleva `.env` ni llaves de la app, pero SI el codigo, incluida la clave de cifrado de `utils/encrypter.js`.
  Cualquiera con la direccion puede leerlo.
- Por HTTP `instalar.sh` puede ser alterado en la red; compare la huella que imprime `armar.sh`:
  `sha256sum /tmp/instalar.sh`

## Estado de pruebas
PostgreSQL real: migraciones sobre bases vacia, vieja, de la 110.67 y el esquema de la Orange del usuario.
WSL con node/npm/psql simulados: nueva, actualizacion, reversa, descarga, paquete alterado e incompleto.
**Sin probar:** una Orange real, y la instalacion real de Node/PostgreSQL con apt.
