#!/bin/bash
# Descarga e instala la ultima version del autoservicio en la Orange.
#   curl -fsSL @URL_BASE@/instalar.sh -o /tmp/instalar.sh && sudo bash /tmp/instalar.sh
# Opciones: instalar.sh [version] [--forzar]
URL_BASE="@URL_BASE@"
NSX=/opt/nsx
[ "$(id -u)" = 0 ] || exec sudo bash "$0" "$@"

PIDE=""; FORZAR=0
for a in "$@"; do case "$a" in --forzar) FORZAR=1;; *) PIDE="$a";; esac; done
falla() { echo "ERROR: $*"; exit 1; }
for h in curl openssl python3; do command -v $h >/dev/null || { apt-get update -qq && apt-get install -y -qq $h; } || falla "Falta $h"; done

lista="$(curl -fsSL -m 30 "$URL_BASE/versions.json?t=$(date +%s)")" || falla "No pude leer $URL_BASE/versions.json"
datos="$(printf '%s' "$lista" | python3 -c '
import json,sys
d=json.load(sys.stdin); v=sys.argv[1] or d["latest"]
x=[e for e in d["versions"] if e["version"]==v]
if not x: sys.exit(1)
print(v, x[-1]["url"], x[-1]["sha256"])' "$PIDE")" || falla "versions.json no tiene la version pedida o esta mal escrito"
read -r VERSION URL SHA <<< "$datos"

if [ $FORZAR = 0 ] && [ "$(tail -1 "$NSX/versiones.txt" 2>/dev/null | cut -d' ' -f1)" = "$VERSION" ]; then
  echo "La Orange ya tiene la version $VERSION. Use --forzar para reinstalarla."
  exit 0
fi

DESCARGAS="$NSX/descargas"; mkdir -p "$DESCARGAS"; chmod 700 "$DESCARGAS"
RUN="$DESCARGAS/autoservicio-orange-$VERSION.run"
echo "Descargando la version $VERSION..."
curl -fL -m 900 --retry 3 -o "$RUN.parcial" "$URL" || falla "No pude descargar $URL"
echo "$SHA  $RUN.parcial" | sha256sum -c --quiet - || falla "El archivo descargado no coincide con versions.json"

# Solo se ejecuta lo firmado por INSEPET
t="$(mktemp -d)"; trap 'rm -rf "$t"' EXIT
cat > "$t/publica.pem" <<'LLAVE'
@LLAVE_PUBLICA@
LLAVE
n="$(grep -a -n -m1 '^__CARGA__$' "$RUN.parcial" | cut -d: -f1)"
[ -n "$n" ] || falla "El archivo no es un paquete del autoservicio"
tail -n +$((n+1)) "$RUN.parcial" > "$t/carga.tgz"
head -n "$n" "$RUN.parcial" | sed -n 's/^#FIRMA://p' | base64 -d > "$t/firma.bin"
openssl dgst -sha256 -verify "$t/publica.pem" -signature "$t/firma.bin" "$t/carga.tgz" >/dev/null 2>&1 || falla "El paquete NO esta firmado por INSEPET. No se instala"
mkdir "$t/paq"; tar -xzf "$t/carga.tgz" -C "$t/paq" || falla "Paquete incompleto"
mv "$RUN.parcial" "$RUN"
ls -1t "$DESCARGAS"/*.run | tail -n +4 | xargs -r rm -f

# orange.config: junto a este script o en la carpeta actual
for c in "$(dirname "$(readlink -f "$0")")/orange.config" "$PWD/orange.config"; do
  [ -f "$c" ] && { cp "$c" "$DESCARGAS/orange.config"; break; }
done
bash "$t/paq/instalar.sh" "$t/paq" "$RUN"
r=$?
echo "Informe: $DESCARGAS"
exit $r
