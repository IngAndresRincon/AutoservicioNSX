#!/bin/bash
# Diagnostico de una Orange. SOLO LEE: no instala, no reinicia ni cambia nada.
# Uso:  sudo bash diagnostico-orange.sh [carpeta_Node]
# Deja diagnostico_<equipo>_<fecha>.tar.gz junto al script. No incluye claves ni datos de la base.
BASE="$1"
if [ -z "$BASE" ]; then
  for c in /home/orangepi/Documents/Node /home/insepet/Documents/Node /home/*/Documents/Node; do
    [ -d "$c/consola" ] && { BASE="$c"; break; }
  done
fi
SELLO="$(date +%Y%m%d_%H%M%S)"
AQUI="$(cd "$(dirname "$0")" && pwd)"
T="$(mktemp -d)"
R="$T/reporte.txt"
SALIDA="$AQUI/diagnostico_$(hostname)_$SELLO.tar.gz"

t() { echo; echo "===== $*"; }
# Oculta claves en texto de unidades y comandos
tapar() { sed -E -e 's/^([[:space:]]*Environment=).*/\1(oculto)/' -e 's/((PASSWORD|SECRET|TOKEN|KEY|CLAVE)[A-Za-z_]*[= :]+)[^ ]+/\1(oculto)/Ig' -e 's#(://)[^/@ ]+@#\1(oculto)@#g'; }
# Igual que dotenv: sin comillas, "#" inicia un comentario
leer_env() { sed -n "s/^[[:space:]]*$2[[:space:]]*=//p" "$1" 2>/dev/null | head -1 | tr -d '\r' | sed -E -e 's/^[[:space:]]+//' -e "/^'/{s/^'([^']*)'.*/\1/;b}" -e '/^"/{s/^"([^"]*)".*/\1/;b}' -e 's/#.*//' -e 's/[[:space:]]+$//'; }

{
t "Sistema"
grep -E '^(PRETTY_NAME|ID|VERSION_ID|VERSION_CODENAME)=' /etc/os-release
echo "arquitectura: $(uname -m) / $(dpkg --print-architecture 2>/dev/null)"
echo "kernel: $(uname -r)"
echo "equipo: $(tr -d '\0' < /proc/device-tree/model 2>/dev/null)"
echo "fecha: $(date '+%F %T %Z')"; timedatectl show -p NTPSynchronized 2>/dev/null
echo "usuario que ejecuta: $(whoami) | systemd: $(ps -p 1 -o comm=)"
free -h | head -2; df -h / "${BASE:-/}" 2>/dev/null

t "Programas"
for c in node npm pm2 psql pg_dump pg_lsclusters curl openssl tar chronyc; do echo "$c: $(command -v $c || echo NO)"; done
command -v node >/dev/null && echo "node (PATH): $(node -v)"
[ -n "$BASE" ] && find "$BASE/nodejs" -maxdepth 3 -name node -type f 2>/dev/null | while read -r n; do echo "$n: $("$n" -v 2>/dev/null)"; done
command -v psql >/dev/null && psql --version
command -v pg_lsclusters >/dev/null && pg_lsclusters
dpkg -l 2>/dev/null | awk '/^ii +(nodejs|postgresql)/{print $2, $3}'
t "Disponible en los repositorios configurados"
apt-cache policy nodejs postgresql 2>/dev/null | grep -E '^[a-z]|Candidate|Candidato'
echo "internet: $(curl -s -o /dev/null -m 6 -w '%{http_code}' http://deb.debian.org/ 2>/dev/null || echo sin salida)"

t "Carpeta de instalacion: ${BASE:-NO ENCONTRADA}"
[ -n "$BASE" ] && ls -la "$BASE"
for c in consola server service terminal nequi pagina gestor_leds; do
  d="$BASE/$c"; [ -d "$d" ] || continue
  t "Componente $c"
  ls -la "$d"; [ -d "$d/src" ] && { echo "src:"; ls "$d/src"; }
  if [ -f "$d/package.json" ]; then
    echo "-- dependencias que pide y no estan en node_modules:"
    sed -n '/"dependencies"/,/}/p' "$d/package.json" | grep -oE '^[[:space:]]*"[^"]+"[[:space:]]*:[[:space:]]*"' | cut -d'"' -f2 | grep -v '^dependencies$' | while read -r dep; do
      [ -f "$d/node_modules/$dep/package.json" ] || echo "   $dep"
    done
  fi
  if [ -f "$d/.env" ]; then
    echo "-- .env (solo nombres; valores ocultos):"
    grep -oE '^[[:space:]]*[A-Za-z_0-9]+' "$d/.env" | tr -d ' ' | while read -r k; do
      v="$(leer_env "$d/.env" "$k")"
      case "$k" in
        API_NSX|DB_HOST|DB_PORT|DB_NAME|DB_DATABASE|DB_SSL|PORT) echo "   $k=$v" | tapar;;
        *) [ -n "$v" ] && echo "   $k (con valor)" || echo "   $k (vacio)";;
      esac
    done
  fi
done

t "Servicios que usan la carpeta o node"
for f in /etc/systemd/system/*.service; do
  [ -f "$f" ] || continue
  if grep -qE "node|${BASE:-__nada__}" "$f"; then
    u="$(basename "$f")"
    echo "--- $u  activo=$(systemctl is-active "$u")  inicia=$(systemctl is-enabled "$u" 2>/dev/null)"
    tapar < "$f"
    ls "$f.d" 2>/dev/null
  fi
done
t "Variables que ponen los servicios (Environment)"
for u in $(grep -l node /etc/systemd/system/*.service 2>/dev/null | xargs -rn1 basename); do
  echo "--- $u"
  systemctl show -p Environment --value "$u" | tr ' ' '\n' | grep = | while IFS= read -r kv; do
    case "${kv%%=*}" in
      NODE_ENV|API_NSX|DB_HOST|DB_PORT|DB_NAME|DB_DATABASE|DB_SSL|PORT|TERMINAL_URL_*) echo "   $kv" | tapar;;
      *) echo "   ${kv%%=*} (con valor)";;
    esac
  done
done

t "Terminal actual: direcciones y tablas que usa"
if [ -d "$BASE/terminal" ]; then
  grep -rhE 'https?://' "$BASE/terminal" --include=*.js --exclude-dir=node_modules 2>/dev/null | grep -oE "https?://[^\"' \`),;?]+" | sort -u | tapar
  grep -rhoiE '(from|join|into|update)[[:space:]]+(public\.)?[a-z_]+' "$BASE/terminal" --include=*.js --exclude-dir=node_modules 2>/dev/null | awk '{print $NF}' | sort | uniq -c
fi

t "Librerias instaladas"
for c in consola server terminal; do
  [ -d "$BASE/$c/node_modules" ] && echo "$c: $(cd "$BASE/$c/node_modules" && for m in * @*/*; do [ -f "$m/package.json" ] && printf '%s ' "$m"; done)"
done

t "Procesos node"
for p in $(pgrep -f 'node|pm2' 2>/dev/null); do
  echo "$p $(ps -o user= -p $p) cwd=$(readlink /proc/$p/cwd) :: $(ps -o args= -p $p)" | tapar
done
t "Arranque alterno"
[ -f /etc/rc.local ] && { echo '/etc/rc.local:'; grep -vE '^[[:space:]]*(#|$)' /etc/rc.local | tapar; }
for u in /root /home/*; do [ -f "$u/.pm2/dump.pm2" ] && echo "pm2 en $u"; done
crontab -l 2>/dev/null | grep -v '^#' | tapar

t "Puertos escuchando"
ss -ltnp 2>/dev/null | awk 'NR>1{print $4, $6}'
t "Red"
ip -4 -o addr show 2>/dev/null | awk '{print $2, $4}'; ip route 2>/dev/null | head -3
ENVC="$BASE/consola/.env"
API="$(leer_env "$ENVC" API_NSX)"
[ -n "$API" ] && echo "API_NSX responde: $(curl -s -o /dev/null -m 8 -w '%{http_code}' "$API")"

t "Base de datos"
if [ -f "$ENVC" ] && command -v psql >/dev/null; then
  export PGPASSWORD="$(leer_env "$ENVC" DB_PASSWORD)"
  H="$(leer_env "$ENVC" DB_HOST)"; P="$(leer_env "$ENVC" DB_PORT)"; U="$(leer_env "$ENVC" DB_USER)"; N="$(leer_env "$ENVC" DB_NAME)"
  H="${H:-localhost}"; P="${P:-5432}"; N="${N:-Autoservicio_nsx2}"
  if psql -h "$H" -p "$P" -U "$U" -d "$N" -w -Atc 'select version()'; then
    psql -h "$H" -p "$P" -U "$U" -d "$N" -w -Atc "select 'tabla ' || tablename || ' (dueno ' || tableowner || ')' from pg_tables where schemaname='public' order by 1"
    echo "usuario de la app es el dueno o superusuario: $(psql -h "$H" -p "$P" -U "$U" -d "$N" -w -Atc 'select rolsuper from pg_roles where rolname=current_user') (super)"
    pg_dump -h "$H" -p "$P" -U "$U" -d "$N" -w --schema-only -f "$T/esquema.sql" && echo "esquema exportado (sin datos)"
  else
    echo "no se pudo conectar con los datos del .env de consola"
  fi
  unset PGPASSWORD
fi
} > "$R" 2>&1

tar -czf "$SALIDA" -C "$T" .
[ -n "${SUDO_USER:-}" ] && chown "$SUDO_USER": "$SALIDA"
[ -n "$BASE" ] && chown "$(stat -c %U "$BASE")": "$SALIDA" 2>/dev/null
chmod 644 "$SALIDA"
rm -rf "$T"
echo "Listo: $SALIDA"
echo "Descargue ese archivo y compartalo."
