#!/bin/bash
# Arma el .run firmado y la carpeta para el servidor. Correr en este PC con Git Bash:
#   bash armar.sh [version] ["que cambio"]
set -e
AQUI="$(cd "$(dirname "$0")" && pwd)"
REPO="${REPO:-$(cd "$AQUI/../.." && pwd)}"
SALIDA="${SALIDA:-$REPO/instalador/Orange/AutoservicioNSX}"
URL_BASE="${URL_BASE:-http://nsx2.insepet.com:82/AutoservicioNSX}"
VERSION="${1:-$(date +%Y%m%d-%H%M)}"
CAMBIOS="${2:-Actualizacion autoservicio}"
# La llave de firma no esta en git. Sin ella no se arma nada (otra llave la rechazan las Orange instaladas)
LLAVE="${LLAVE:-/d/TeamsInsepet/Autoservicio/Orange/actualizador/llave/privada.pem}"

if [ ! -f "$LLAVE" ]; then
  [ "${CREAR_LLAVE:-}" = 1 ] || { echo "No encuentro la llave de firma ($LLAVE). Indique LLAVE=/ruta/privada.pem (o CREAR_LLAVE=1 para una nueva)"; exit 1; }
  mkdir -p "$(dirname "$LLAVE")"
  openssl genrsa -out "$LLAVE" 3072 2>/dev/null
  echo "Se creo la llave de firma en $LLAVE. Guardela y respaldela."
fi

T="$(mktemp -d)"; P="$T/paq"; mkdir -p "$P/codigo" "$P/vigilante"
# destino en la Orange : carpeta en el repo.  docs y *.md no se publican (traen una llave de ejemplo)
for par in consola:consola server:service terminal:terminal; do
  d="${par%:*}"; o="${par#*:}"
  mkdir -p "$P/codigo/$d"
  (cd "$REPO/$o" && tar -cf - --exclude=node_modules --exclude='.env' --exclude='.env.*' --exclude=.gitignore --exclude=docs --exclude='*.md' --exclude=logs --exclude='*.log' --exclude='*.zip' --exclude=test .) | tar -xf - -C "$P/codigo/$d"
  node --check "$P/codigo/$d/$([ $d = terminal ] && echo src/index.js || { [ $d = server ] && echo server.js || echo index.js; })"
done
grep -vE '^(func|trigger):' "$AQUI/esquema_requerido.txt" | tr -d '\r' > "$P/columnas.txt"
cp "$AQUI/instalar.sh" "$AQUI/preparar.sh" "$P/"
cp "$AQUI/vigilante/"*.sh "$P/vigilante/"
openssl rsa -in "$LLAVE" -pubout -out "$P/vigilante/publica.pem" 2>/dev/null
echo "$VERSION" > "$P/VERSION"
# los scripts deben quedar con fin de linea Linux
find "$P" \( -name "*.sh" -o -name "*.sql" -o -name columnas.txt -o -name VERSION \) -print0 | xargs -0 sed -i "s/\r$//"

tar -czf "$T/carga.tgz" -C "$P" .
FIRMA="$(openssl dgst -sha256 -sign "$LLAVE" "$T/carga.tgz" | base64 -w0)"

mkdir -p "$SALIDA"
NOMBRE="autoservicio-orange-$VERSION.run"
RUN="$SALIDA/$NOMBRE"
{
cat <<'EOF'
#!/bin/bash
# Autoservicio NSX - paquete para la Orange.  Primera vez:  sudo bash este_archivo.run
[ "$(id -u)" = 0 ] || exec sudo bash "$0" "$@"
t="$(mktemp -d)"; trap 'rm -rf "$t"' EXIT
n="$(grep -a -n -m1 '^__CARGA__$' "$0" | cut -d: -f1)"
tail -n +$((n+1)) "$0" | tar -xzf - -C "$t" || { echo "El archivo esta incompleto"; exit 1; }
bash "$t/instalar.sh" "$t" "$0"
exit $?
EOF
echo "#FIRMA:$FIRMA"
echo "__CARGA__"
cat "$T/carga.tgz"
} > "$RUN"

# instalar.sh que se descarga desde el servidor, con la direccion y la llave publica
openssl rsa -in "$LLAVE" -pubout 2>/dev/null | tr -d '\r' > "$T/publica.pem"
tr -d '\r' < "$AQUI/arranque.sh" | awk -v url="$URL_BASE" -v llave="$T/publica.pem" '
  $0=="@LLAVE_PUBLICA@" { while ((getline l < llave) > 0) print l; next }
  { gsub(/@URL_BASE@/, url); print }' > "$SALIDA/instalar.sh"

# versions.json: mismo formato que el de los APK, mas la huella del archivo
SHA="$(sha256sum "$RUN" | cut -d' ' -f1)"
(cd "$SALIDA" && V="$VERSION" U="$URL_BASE/$NOMBRE" S="$SHA" C="$CAMBIOS" F="$(date +%F)" node -e '
  const fs=require("fs"),e=process.env;
  const d=fs.existsSync("versions.json")?JSON.parse(fs.readFileSync("versions.json","utf8")):{versions:[]};
  d.versions=d.versions.filter(v=>v.version!==e.V);
  d.versions.push({version:e.V,buildNumber:1,url:e.U,sha256:e.S,changelog:e.C,date:e.F,stable:true});
  d.latest=e.V; fs.writeFileSync("versions.json",JSON.stringify(d,null,2)+"\n");')

# IIS no entrega extensiones que no conozca
cat > "$SALIDA/web.config" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
  <system.webServer>
    <staticContent>
      <remove fileExtension=".run" /><mimeMap fileExtension=".run" mimeType="application/octet-stream" />
      <remove fileExtension=".sh" /><mimeMap fileExtension=".sh" mimeType="text/plain" />
      <remove fileExtension=".json" /><mimeMap fileExtension=".json" mimeType="application/json" />
    </staticContent>
  </system.webServer>
</configuration>
EOF
rm -rf "$T"
echo "Listo: $RUN ($(du -h "$RUN" | cut -f1))"
echo "Suba al servidor la carpeta: $SALIDA"
echo "Huella de instalar.sh: $(sha256sum "$SALIDA/instalar.sh" | cut -d' ' -f1)"
