#!/bin/bash
# Instala/actualiza el autoservicio en la Orange. Lo ejecuta el .run (manual la primera vez, luego el vigilante).
# Uso interno: instalar.sh <carpeta_extraida> <ruta_del_run>
set -u
PAQ="$1"; RUN="$(readlink -f "$2")"
VERSION="$(cat "$PAQ/VERSION")"
SELLO="$(date +%Y%m%d_%H%M%S)"
NSX=/opt/nsx
AVISOS=0
CAMBIOS=0          # 1 desde que se toca algo: habilita la reversa
declare -A DIR UNIDAD ENTRADA ACTIVA_ANTES
ENTRADA=([consola]=index.js [server]=server.js [terminal]=src/index.js)

[ "$(id -u)" = 0 ] || { echo "Ejecute con sudo: sudo bash $RUN"; exit 1; }

# ---------- configuracion opcional junto al .run ----------
CONF="$(dirname "$RUN")/orange.config"
[ -f "$CONF" ] || CONF="$NSX/orange.config"
conf() { [ -f "$CONF" ] && sed -n "s/^[[:space:]]*$1[[:space:]]*=[[:space:]]*//p" "$CONF" | tail -1 | tr -d '\r'; }

BASE="$(conf BASE)"
[ -z "$BASE" ] && [ -f "$NSX/base" ] && BASE="$(cat "$NSX/base")"
if [ -z "$BASE" ]; then
  for c in /home/orangepi/Documents/Node /home/insepet/Documents/Node /home/*/Documents/Node; do
    [ -d "$c/consola" ] && { BASE="$c"; break; }
  done
fi

LOGDIR="$NSX/logs"; mkdir -p "$LOGDIR"
LOG="$LOGDIR/instalacion_$SELLO.log"
exec > >(tee -a "$LOG") 2>&1

paso()  { echo; echo "== $*"; }
ok()    { echo "  OK    $*"; }
aviso() { echo "  AVISO $*"; AVISOS=$((AVISOS+1)); }

informe() {  # $1 = OK | ERROR
  local destino="$(dirname "$RUN")/$(basename "$RUN" .run)_${SELLO}_$1.txt"
  sleep 1; cp "$LOG" "$destino" 2>/dev/null
  [ -n "${DUENO:-}" ] && chown "$DUENO" "$destino" 2>/dev/null
}

error() {
  echo "  ERROR $*"
  [ "$CAMBIOS" = 1 ] && revertir
  echo; echo "RESULTADO: ERROR (version $VERSION). Detalle en $LOG"
  informe ERROR
  exit 1
}

revertir() {
  CAMBIOS=0
  paso "Reversa al codigo anterior"
  for c in "${!DIR[@]}"; do
    local d="${DIR[$c]}" t="$RESPALDO/$c.tar.gz"
    [ -f "$t" ] || continue
    find "$d" -mindepth 1 -maxdepth 1 ! -name node_modules ! -name public -exec rm -rf {} +
    tar -xzf "$t" -C "$d" && ok "$c restaurado"
  done
  for u in "${NUEVAS[@]:-}"; do
    [ -n "$u" ] && { systemctl disable --now "$u" >/dev/null 2>&1; rm -f "/etc/systemd/system/$u"; }
  done
  rm -f "${DROPINS[@]:-/dev/null/x}" 2>/dev/null
  systemctl daemon-reload
  for c in "${!UNIDAD[@]}"; do
    [ "${ACTIVA_ANTES[$c]:-no}" = si ] && timeout 120 systemctl restart "${UNIDAD[$c]}"
  done
  echo "  La base de datos solo recibio cambios que agregan (no se borra nada). Copia previa: $RESPALDO/bd.dump"
}
NUEVAS=(); DROPINS=()

echo "Autoservicio NSX - paquete $VERSION - $(date '+%Y-%m-%d %H:%M:%S')"

# Igual que dotenv: sin comillas, "#" inicia un comentario
leer_env() { [ -f "$1" ] && sed -n "s/^[[:space:]]*$2[[:space:]]*=//p" "$1" | head -1 | tr -d '\r' | sed -E -e 's/^[[:space:]]+//' -e "/^'/{s/^'([^']*)'.*/\1/;b}" -e '/^"/{s/^"([^"]*)".*/\1/;b}' -e 's/#.*//' -e 's/[[:space:]]+$//'; }
. "$PAQ/preparar.sh"

# ====================================================================
paso "1. Revision (todavia no se cambia nada)"
[ -n "$BASE" ] && [ -d "$BASE" ] || error "No encuentro la carpeta de instalacion. Cree orange.config con BASE=/ruta/Node"
ok "Carpeta: $BASE"
DUENO="$(stat -c %U "$BASE")"

DIR[consola]="$BASE/consola"
if [ -d "$BASE/server" ]; then DIR[server]="$BASE/server"
elif [ -d "$BASE/service" ]; then DIR[server]="$BASE/service"
else error "No existe $BASE/server ni $BASE/service"; fi
DIR[terminal]="$BASE/terminal"
[ -d "${DIR[consola]}" ] || error "No existe ${DIR[consola]}"
[ -d "${DIR[terminal]}" ] || { aviso "No existe $BASE/terminal: no se instala el terminal"; unset "DIR[terminal]"; }

# Servicios systemd que trabajan en cada carpeta
for c in "${!DIR[@]}"; do
  d="${DIR[$c]}"
  for f in /etc/systemd/system/*.service; do
    [ -f "$f" ] || continue
    u="$(basename "$f")"
    txt="$(systemctl show -p WorkingDirectory -p ExecStart "$u" 2>/dev/null)"
    if echo "$txt" | grep -qE "(^WorkingDirectory=[-!]*$d/?$)|( $d/[^ ;]*\.js)"; then UNIDAD[$c]="$u"; break; fi
  done
  if [ -n "${UNIDAD[$c]:-}" ]; then
    systemctl is-active -q "${UNIDAD[$c]}" && ACTIVA_ANTES[$c]=si || ACTIVA_ANTES[$c]=no
    ok "$c -> ${UNIDAD[$c]} (activo antes: ${ACTIVA_ANTES[$c]})"
  fi
done

# Procesos node que corren desde una carpeta sin servicio (pm2, rc.local, etc.)
declare -A SUELTO
for c in "${!DIR[@]}"; do
  [ -n "${UNIDAD[$c]:-}" ] && continue
  for p in $(pgrep -f node || true); do
    [ "$(readlink -f /proc/$p/cwd 2>/dev/null)" = "$(readlink -f "${DIR[$c]}")" ] && SUELTO[$c]=$p
  done
done

# Node: el del servicio, el del PATH o el de la carpeta nodejs
NODE=""
for c in "${!UNIDAD[@]}"; do
  n="$(systemctl show -p ExecStart --value "${UNIDAD[$c]}" | sed -n 's/.*path=\([^ ;]*\).*/\1/p')"
  case "$n" in */node) [ -x "$n" ] && NODE="$n"; [ -n "$NODE" ] && break;; esac
done
[ -z "$NODE" ] && NODE="$(command -v node || true)"
[ -z "$NODE" ] && NODE="$(ls "$BASE"/nodejs/bin/node "$BASE"/nodejs/*/bin/node 2>/dev/null | head -1)"
[ -x "$NODE" ] || error "No encuentro Node.js"
ok "Node $("$NODE" -v) ($NODE)"
[ "$("$NODE" -p 'process.versions.node.split(".")[0]')" -ge 16 ] || error "Se necesita Node 16 o superior"

for h in psql pg_dump tar; do command -v $h >/dev/null || error "Falta el comando $h"; done
LIBRE=$(df -Pm "$BASE" | awk 'NR==2{print $4}')
[ "$LIBRE" -ge 500 ] || error "Poco espacio libre: ${LIBRE} MB (se piden 500)"
ok "Espacio libre: ${LIBRE} MB"
[ "$(date +%Y)" -ge 2026 ] || aviso "El reloj de la Orange esta en $(date '+%Y-%m-%d'): sincronice la hora"

# Librerias que pide la version nueva: las que falten se descargan aparte y se copian en el paso 4
for c in "${!DIR[@]}"; do
  faltan="$("$NODE" -e '
    const fs=require("fs"),p=require("path");
    const deps=Object.keys(require(process.argv[1]).dependencies||{});
    console.log(deps.filter(d=>!fs.existsSync(p.join(process.argv[2],"node_modules",d,"package.json"))).join(" "))
  ' "$PAQ/codigo/$c/package.json" "${DIR[$c]}")" || error "No pude revisar las librerias de $c"
  [ -n "$faltan" ] || continue
  NPM="$(dirname "$NODE")/npm"; [ -x "$NPM" ] || NPM="$(command -v npm || true)"
  [ -n "$NPM" ] || error "A $c le faltan librerias y no encuentro npm"
  echo "  Descargando librerias de $c..."
  mkdir -p "$PAQ/libs/$c"; cp "$PAQ/codigo/$c"/package*.json "$PAQ/libs/$c/"
  (cd "$PAQ/libs/$c" && PATH="$(dirname "$NODE"):$PATH" && { "$NPM" ci --omit=dev --no-audit --no-fund >/dev/null 2>&1 || "$NPM" install --omit=dev --no-audit --no-fund; }) \
    || error "No pude descargar las librerias de $c (hay internet?)"
done
ok "Librerias de Node completas"

# ---------- .env ----------
ENVC="${DIR[consola]}/.env"; ENVS="${DIR[server]}/.env"
[ -f "$ENVC" ] || error "Falta $ENVC"
[ -f "$ENVS" ] || error "Falta $ENVS"
faltan=""
for k in API_NSX IDENTIFIER MAC; do [ -n "$(leer_env "$ENVC" $k)$(conf $k)" ] || faltan="$faltan consola:$k"; done
for k in API_KEYS IO_API_KEY; do [ -n "$(leer_env "$ENVS" $k)" ] || faltan="$faltan server:$k"; done
[ -z "$faltan" ] || error "Faltan datos propios de la estacion en los .env:$faltan"

DB_HOST="$(leer_env "$ENVC" DB_HOST)"; DB_HOST="${DB_HOST:-localhost}"
DB_PORT="$(leer_env "$ENVC" DB_PORT)"; DB_PORT="${DB_PORT:-5432}"
DB_USER="$(leer_env "$ENVC" DB_USER)"; DB_PASSWORD="$(leer_env "$ENVC" DB_PASSWORD)"
DB_NAME="$(leer_env "$ENVC" DB_NAME)"; DB_NAME="${DB_NAME:-Autoservicio_nsx2}"
export PGPASSWORD="$DB_PASSWORD"
sql_app() { psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -X -q -v ON_ERROR_STOP=1 "$@"; }
sql_app -Atc 'select 1' >/dev/null || error "No me puedo conectar a la base $DB_NAME en $DB_HOST con el usuario del .env"
ok "Base de datos $DB_NAME"

# Si la BD es local, las migraciones corren como postgres y a nombre del dueno de las tablas
LOCAL=no; case "$DB_HOST" in localhost|127.0.0.1|::1) LOCAL=si;; esac
SUPER=no
if [ $LOCAL = si ] && id postgres >/dev/null 2>&1 && runuser -u postgres -- psql -p "$DB_PORT" -d "$DB_NAME" -Atqc 'select 1' >/dev/null 2>&1; then SUPER=si; fi
ROL="$(sql_app -Atc "select tableowner from pg_tables where schemaname='public' and tablename in ('autorizacion','programacion') limit 1")"

# ====================================================================
paso "2. Respaldo"
RESPALDO="$NSX/respaldos/$SELLO"; mkdir -p "$RESPALDO"; chmod 700 "$RESPALDO"
for c in "${!DIR[@]}"; do
  tar -czf "$RESPALDO/$c.tar.gz" -C "${DIR[$c]}" --exclude=./node_modules --exclude=./public . || error "No pude respaldar $c"
done
ok "Codigo"
pg_dump -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -Fc -f "$RESPALDO/bd.dump" || error "No pude respaldar la base de datos"
ok "Base de datos"
ls -1dt "$NSX"/respaldos/*/ 2>/dev/null | tail -n +6 | xargs -r rm -rf

# ====================================================================
paso "3. Base de datos"
for f in "$PAQ"/codigo/consola/database/migrations/*.sql; do
  if [ $SUPER = si ]; then
    { [ -n "$ROL" ] && echo "SET ROLE \"$ROL\";"; cat "$f"; } | runuser -u postgres -- psql -p "$DB_PORT" -d "$DB_NAME" -X -q -v ON_ERROR_STOP=1 >/dev/null || error "Fallo la migracion $(basename "$f")"
  else
    sql_app -f "$f" >/dev/null || error "Fallo la migracion $(basename "$f") con el usuario $DB_USER"
  fi
  ok "$(basename "$f")"
done
if [ $SUPER = si ] && [ -n "$ROL" ] && [ "$ROL" != "$DB_USER" ]; then
  runuser -u postgres -- psql -p "$DB_PORT" -d "$DB_NAME" -X -q -v ON_ERROR_STOP=1 \
    -c "GRANT ALL ON ALL TABLES IN SCHEMA public TO \"$DB_USER\"; GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO \"$DB_USER\";" || error "No pude dar permisos a $DB_USER"
fi

faltan="$(while read -r t col; do
    [ -n "$t" ] && echo "('$t','$col')"
  done < <(tr '.' ' ' < "$PAQ/columnas.txt") | paste -sd, - | { read -r v; sql_app -Atc "
    select r.t||'.'||r.c from (values $v) r(t,c)
    where not exists (select 1 from information_schema.columns k where k.table_schema='public' and k.table_name=r.t and k.column_name=r.c)"; })" \
  || error "No pude verificar el esquema"
[ -z "$faltan" ] || error "Despues de migrar siguen faltando columnas: $(echo $faltan)"
ok "Esquema completo ($(grep -c . "$PAQ/columnas.txt") columnas verificadas)"

# Sin la fila del modulo la consola nunca sincroniza el mapeo; solo se crea si no hay ninguna
ID_MODULO="$(leer_env "$ENVC" IDENTIFIER)"
echo "insert into public.modulo (identificador, sincronizar, activo) select left(:'id',20), true, true where not exists (select 1 from public.modulo);" \
  | sql_app -v id="$ID_MODULO" >/dev/null || error "No pude registrar el modulo"
ok "Datos iniciales"

# ====================================================================
paso "4. Codigo"
CAMBIOS=1
for c in "${!DIR[@]}"; do
  d="${DIR[$c]}"; u="$(stat -c %U:%G "$d")"
  [ -n "${UNIDAD[$c]:-}" ] && timeout 150 systemctl stop "${UNIDAD[$c]}"
  (cd "$PAQ/codigo/$c" && tar -cf - --exclude=./public .) | tar -xf - -C "$d" --no-same-owner || error "No pude copiar $c"
  # public tiene audios, imagenes y videos de la estacion: solo se agrega lo que no exista
  if [ -d "$PAQ/codigo/$c/public" ]; then
    mkdir -p "$d/public"; cp -rn "$PAQ/codigo/$c/public/." "$d/public/" 2>/dev/null
  fi
  if [ -d "$PAQ/libs/$c/node_modules" ]; then
    mkdir -p "$d/node_modules"; cp -a "$PAQ/libs/$c/node_modules/." "$d/node_modules/" || error "No pude copiar las librerias de $c"
  fi
  chown -R "$u" "$d"
  ok "$c"
done

# ====================================================================
paso "5. Configuracion (.env)"
poner() {  # archivo clave valor [reemplazar]
  [ -n "$3" ] || return 0
  local linea="$3"; case "$3" in *"#"*) linea="'$3'";; esac
  if grep -qE "^[[:space:]]*$2[[:space:]]*=" "$1"; then
    if [ -n "${4:-}" ] || [ -z "$(leer_env "$1" "$2")" ]; then
      [ "$(leer_env "$1" "$2")" = "$3" ] && return 0
      VAL="$linea" K="$2" awk '$0 ~ "^[[:space:]]*" ENVIRON["K"] "[[:space:]]*=" {print ENVIRON["K"] "=" ENVIRON["VAL"]; next} {print}' "$1" > "$1.tmp" && cat "$1.tmp" > "$1" && rm -f "$1.tmp"
      echo "  .env  $(basename "$(dirname "$1")"): $2 actualizado"
    fi
  else
    [ -s "$1" ] && [ -n "$(tail -c1 "$1")" ] && echo >> "$1"
    printf '%s=%s\n' "$2" "$linea" >> "$1"
    echo "  .env  $(basename "$(dirname "$1")"): $2 agregado"
  fi
}
for k in API_NSX MAC IDENTIFIER; do
  v="$(conf $k)"; [ -n "$v" ] && poner "$ENVC" $k "$v" si
done
v="$(conf API_NSX)"; [ -n "$v" ] && poner "$ENVS" API_NSX "$v" si
poner "$ENVS" API_NSX "$(leer_env "$ENVC" API_NSX)"
poner "$ENVS" PORT 5007
poner "$ENVS" JWT_SECRET "$(head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n')"
poner "$ENVS" REFRESH_SECRET "$(head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n')"
for k in DB_HOST DB_PORT DB_USER DB_PASSWORD DB_NAME; do poner "$ENVS" $k "$(leer_env "$ENVC" $k)"; done
if [ -n "${DIR[terminal]:-}" ]; then
  ENVT="${DIR[terminal]}/.env"
  [ -f "$ENVT" ] || { : > "$ENVT"; chown "$(stat -c %U:%G "${DIR[terminal]}")" "$ENVT"; }
  poner "$ENVT" DB_HOST "$DB_HOST"; poner "$ENVT" DB_PORT "$DB_PORT"
  poner "$ENVT" DB_USER "$DB_USER"; poner "$ENVT" DB_PASSWORD "$DB_PASSWORD"
  poner "$ENVT" DB_DATABASE "$DB_NAME"; poner "$ENVT" DB_SSL false
  poner "$ENVT" IDENTIFIER "$(leer_env "$ENVC" IDENTIFIER)"
  poner "$ENVT" TERMINAL_URL_PAYMENT 'http://[urlbase]/api/payment'
  poner "$ENVT" TERMINAL_URL_STATUS_PAYMENT 'http://[urlbase]/api/payment/transaction/'
  poner "$ENVT" TERMINAL_URL_PLEDGE 'http://[urlbase]/api/approve/payment/'
fi
API="$(leer_env "$ENVC" API_NSX)"
ok "API_NSX = $API"

# ====================================================================
paso "6. Servicios"
for c in consola server terminal; do
  d="${DIR[$c]:-}"; [ -n "$d" ] || continue
  e="${ENTRADA[$c]}"; [ -f "$d/$e" ] || error "El paquete no trae $c/$e"
  u="${UNIDAD[$c]:-}"
  if [ -n "$u" ]; then
    # Si el servicio arrancaba otro archivo (version vieja) se corrige sin tocar la unidad original
    if ! systemctl show -p ExecStart --value "$u" | grep -qE "(argv\[\]=.* ($d/)?$e( |;|$))|npm"; then
      mkdir -p "/etc/systemd/system/$u.d"
      printf '[Service]\nWorkingDirectory=%s\nExecStart=\nExecStart=%s %s/%s\n' "$d" "$NODE" "$d" "$e" > "/etc/systemd/system/$u.d/insepet.conf"
      DROPINS+=("/etc/systemd/system/$u.d/insepet.conf")
      echo "  $u ahora arranca $e"
    fi
  elif [ -n "${SUELTO[$c]:-}" ]; then
    aviso "$c corre sin servicio systemd (proceso ${SUELTO[$c]}): reinicielo a mano o reinicie la Orange"
  else
    u="autoservicensx-$c.service"
    printf '[Unit]\nDescription=Autoservicio INSEPET %s\nAfter=network.target postgresql.service\n\n[Service]\nUser=%s\nWorkingDirectory=%s\nExecStart=%s %s/%s\nEnvironment=NODE_ENV=production\nRestart=always\nRestartSec=5\n\n[Install]\nWantedBy=multi-user.target\n' \
      "$c" "$(stat -c %U "$d")" "$d" "$NODE" "$d" "$e" > "/etc/systemd/system/$u"
    UNIDAD[$c]="$u"; NUEVAS+=("$u")
    echo "  No habia servicio para $c: se creo $u"
  fi
done
systemctl daemon-reload

declare -A REINICIOS
for c in "${!UNIDAD[@]}"; do
  systemctl enable "${UNIDAD[$c]}" >/dev/null 2>&1
  timeout 150 systemctl restart "${UNIDAD[$c]}" || error "No arranco ${UNIDAD[$c]}"
done
sleep 5
for c in "${!UNIDAD[@]}"; do REINICIOS[$c]="$(systemctl show -p NRestarts --value "${UNIDAD[$c]}")"; done
sleep 20

# ====================================================================
paso "7. Verificacion"
for c in "${!UNIDAD[@]}"; do
  u="${UNIDAD[$c]}"
  if systemctl is-active -q "$u" && [ "$(systemctl show -p NRestarts --value "$u")" = "${REINICIOS[$c]}" ]; then
    ok "$u activo y estable"
  else
    journalctl -u "$u" -n 25 --no-pager
    error "$u no quedo estable"
  fi
done
PUERTO="$(leer_env "$ENVS" PORT)"
if [ -n "${UNIDAD[server]:-}" ]; then
  codigo=000
  for i in 1 2 3 4 5 6; do
    codigo="$(curl -s -o /dev/null -m 5 -w '%{http_code}' "http://127.0.0.1:$PUERTO/" || true)"
    [ "$codigo" != 000 ] && break; sleep 5
  done
  if [ "$codigo" = 000 ]; then
    journalctl -u "${UNIDAD[server]}" -n 25 --no-pager
    error "server no responde en el puerto $PUERTO"
  fi
  ok "server responde en el puerto $PUERTO"
fi
codigo="$(curl -s -o /dev/null -m 10 -w '%{http_code}' "$API" || true)"
if [ -z "$codigo" ] || [ "$codigo" = 000 ]; then aviso "La Orange no llega al API ($API). Revise red, IP y firewall del servidor"; else ok "Llega al API ($API)"; fi
for c in "${!UNIDAD[@]}"; do
  n="$(journalctl -u "${UNIDAD[$c]}" --since '-30 sec' --no-pager 2>/dev/null | grep -ciE 'error|exception' || true)"
  if [ "${n:-0}" -gt 0 ]; then
    aviso "$c escribio $n lineas con error al arrancar; las ultimas:"
    journalctl -u "${UNIDAD[$c]}" --since '-30 sec' --no-pager | grep -iE 'error|exception' | tail -3
  fi
done
CAMBIOS=0

# ====================================================================
paso "8. Instalacion automatica para la proxima vez"
echo "$BASE" > "$NSX/base"
bash "$PAQ/vigilante/instalar_vigilante.sh" "$PAQ" "$BASE" "$DUENO" && ok "Deje los proximos .run en $BASE/actualizar" || aviso "No pude dejar el vigilante"
echo "$VERSION $SELLO" >> "$NSX/versiones.txt"

echo
if [ $AVISOS = 0 ]; then echo "RESULTADO: OK (version $VERSION)"
else echo "RESULTADO: OK con $AVISOS aviso(s) (version $VERSION)"; fi
echo "Falta: sincronizar el mapeo (la consola lo hace sola cuando el modulo lo pide) y reiniciar la app en la tablet."
informe OK
