# Deja lo que falte antes de instalar: programas, base de datos, carpetas y .env.  Lo carga instalar.sh.
# En una Orange ya instalada no cambia nada de lo que exista.
APT_LISTO=0
instalar_paquetes() {
  command -v apt-get >/dev/null || error "Falta $* y esta Orange no usa apt: instalelo a mano"
  if [ $APT_LISTO = 0 ]; then apt-get update -qq || error "No pude actualizar la lista de paquetes (hay internet?)"; APT_LISTO=1; fi
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "$@" || error "No pude instalar: $*"
}

# Dato de la estacion: orange.config, y si hay alguien en la terminal se pregunta
pedir() {  # variable texto [defecto]
  local v; v="$(conf "$1")"
  if [ -z "$v" ] && [ -t 0 ]; then
    printf '  %s%s: ' "$2" "${3:+ [$3]}" > /dev/tty; read -r v < /dev/tty
  fi
  [ -n "$v" ] || v="${3:-}"
  printf -v "$1" '%s' "$v"
}

if [ -z "$BASE" ]; then
  if id orangepi >/dev/null 2>&1; then BASE=/home/orangepi/Documents/Node
  elif [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != root ]; then BASE="/home/$SUDO_USER/Documents/Node"
  else error "No se donde instalar. Cree orange.config con BASE=/ruta/Node"; fi
fi
ENVC="$BASE/consola/.env"
DIR_SERVER="$BASE/server"; [ ! -d "$DIR_SERVER" ] && [ -d "$BASE/service" ] && DIR_SERVER="$BASE/service"
NUEVA=0; [ -f "$ENVC" ] || NUEVA=1

paso "0. Preparacion"
if [ $NUEVA = 1 ]; then
  echo "  Instalacion nueva en $BASE"
  # Todos los datos se piden antes de instalar nada
  iface="$(ip route show default 2>/dev/null | awk '{print $5; exit}')"
  mac_equipo="$(tr -d ':\n' < "/sys/class/net/${iface:-eth0}/address" 2>/dev/null | tr 'a-f' 'A-F')"
  pedir API_NSX "URL del API (ej. http://192.168.1.10:8070/api)"
  pedir MAC "MAC de la Orange" "$mac_equipo"
  pedir API_KEYS "API_KEYS (llave de la app)"
  pedir IO_API_KEY "IO_API_KEY (llave de la app para avisos)"
  faltan=""; for k in API_NSX MAC API_KEYS IO_API_KEY; do [ -n "${!k}" ] || faltan="$faltan $k"; done
  [ -z "$faltan" ] || error "Faltan datos:$faltan. Pongalos en orange.config junto al .run, o ejecutelo desde una terminal"
  IDENTIFIER="$(conf IDENTIFIER)"; IDENTIFIER="${IDENTIFIER:-$MAC}"
fi

for h in curl openssl tar; do command -v $h >/dev/null || instalar_paquetes $h; done

if ! command -v node >/dev/null && ! ls "$BASE"/nodejs/bin/node "$BASE"/nodejs/*/bin/node >/dev/null 2>&1; then
  echo "  Instalando Node.js 20..."
  instalar_paquetes ca-certificates
  t="$(mktemp)"
  curl -fsSL https://deb.nodesource.com/setup_20.x -o "$t" && bash "$t" >/dev/null || error "No pude agregar el repositorio de Node.js"
  rm -f "$t"; APT_LISTO=0
  instalar_paquetes nodejs
  ok "Node.js instalado"
fi

# Base de datos: siempre usuario postgres y clave admin en instalaciones nuevas
if [ $NUEVA = 1 ]; then
  DB_HOST=localhost; DB_PORT=5432; DB_USER=postgres; DB_PASSWORD=admin
  DB_NAME="$(conf DB_NAME)"; DB_NAME="${DB_NAME:-autoservicionsx}"
else
  DB_HOST="$(leer_env "$ENVC" DB_HOST)"; DB_HOST="${DB_HOST:-localhost}"
  DB_PORT="$(leer_env "$ENVC" DB_PORT)"; DB_PORT="${DB_PORT:-5432}"
  DB_USER="$(leer_env "$ENVC" DB_USER)"; DB_PASSWORD="$(leer_env "$ENVC" DB_PASSWORD)"
  DB_NAME="$(leer_env "$ENVC" DB_NAME)"; DB_NAME="${DB_NAME:-autoservicionsx}"
fi
LOCAL=no; case "$DB_HOST" in localhost|127.0.0.1|::1) LOCAL=si;; esac

PG_NUEVO=0
if [ $LOCAL = si ] && ! ls /usr/lib/postgresql/*/bin/postgres >/dev/null 2>&1 && ! command -v psql >/dev/null; then
  echo "  Instalando PostgreSQL..."
  instalar_paquetes postgresql
  PG_NUEVO=1
  ok "PostgreSQL instalado"
fi
for h in psql pg_dump; do command -v $h >/dev/null || instalar_paquetes postgresql-client; done
[ $LOCAL = si ] && systemctl enable --now postgresql >/dev/null 2>&1

export PGPASSWORD="$DB_PASSWORD"
entra() { psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d postgres -w -Atqc 'select 1' >/dev/null 2>&1; }
if [ $LOCAL = si ]; then
  for i in 1 2 3 4 5 6; do pg_isready -h "$DB_HOST" -p "$DB_PORT" -q 2>/dev/null && break; command -v pg_isready >/dev/null || break; sleep 5; done
fi
if [ $NUEVA = 1 ] && ! entra; then
  cambiar=s
  if [ $PG_NUEVO = 0 ]; then
    # PostgreSQL que ya estaba: otra aplicacion podria usar la clave actual
    cambiar=n
    if [ -t 0 ]; then printf '  postgres no acepta la clave admin. Ponersela? (s/N): ' > /dev/tty; read -r cambiar < /dev/tty; fi
  fi
  case "$cambiar" in
    s|S) runuser -u postgres -- psql -p "$DB_PORT" -Xqc "ALTER USER postgres PASSWORD 'admin'" || error "No pude poner la clave a postgres";;
    *) error "postgres no acepta la clave admin";;
  esac
fi
entra || error "No me puedo conectar a PostgreSQL en $DB_HOST con el usuario del .env"
if [ "$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d postgres -w -AtqXc "select 1 from pg_database where datname='$DB_NAME'")" != 1 ]; then
  psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d postgres -w -Xqc "CREATE DATABASE \"$DB_NAME\"" || error "No pude crear la base $DB_NAME"
  ok "Base $DB_NAME creada"
fi

# Carpetas y .env que falten
if [ $NUEVA = 1 ]; then
  usuario="$(echo "$BASE" | sed -n 's#^/home/\([^/]*\)/.*#\1#p')"; id "$usuario" >/dev/null 2>&1 || usuario="${SUDO_USER:-root}"
  [ -d "$BASE" ] || { mkdir -p "$BASE"; chown "$usuario": "$(dirname "$BASE")" "$BASE"; }
fi
usuario="$(stat -c %U "$BASE" 2>/dev/null)"
for d in "$BASE/consola" "$DIR_SERVER" "$BASE/terminal"; do
  [ -d "$d" ] || { mkdir -p "$d"; chown "$usuario": "$d"; echo "  Carpeta $d creada"; }
done
if [ $NUEVA = 1 ]; then
  entre_comillas() { case "$1" in *"#"*) printf "'%s'" "$1";; *) printf '%s' "$1";; esac; }
  datos_bd() { printf 'DB_HOST=%s\nDB_PORT=%s\nDB_USER=%s\nDB_PASSWORD=%s\nDB_NAME=%s\n' "$DB_HOST" "$DB_PORT" "$DB_USER" "$DB_PASSWORD" "$DB_NAME"; }
  { printf 'API_NSX=%s\nIDENTIFIER=%s\nMAC=%s\n' "$API_NSX" "$IDENTIFIER" "$MAC"; datos_bd; } > "$ENVC"
  if [ ! -f "$DIR_SERVER/.env" ]; then
    { printf 'API_KEYS=%s\nIO_API_KEY=%s\nAPI_NSX=%s\nPORT=5007\n' "$(entre_comillas "$API_KEYS")" "$(entre_comillas "$IO_API_KEY")" "$API_NSX"; datos_bd; echo 'DB_SSL=false'; } > "$DIR_SERVER/.env"
  fi
  chown "$usuario": "$ENVC" "$DIR_SERVER/.env"; chmod 640 "$ENVC" "$DIR_SERVER/.env"
  ok ".env creados"
fi
