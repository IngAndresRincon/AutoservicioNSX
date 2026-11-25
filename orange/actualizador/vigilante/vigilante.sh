#!/bin/bash
# Procesa los .run de la carpeta. Solo instala los firmados por INSEPET: corre como root.
CARPETA="$1"; NSX=/opt/nsx
HECHOS="$CARPETA/procesados"; mkdir -p "$HECHOS" "$NSX/trabajo"
shopt -s nullglob
for f in "$CARPETA"/*.run; do
  # Esperar a que termine de copiarse
  antes=-1
  while [ -f "$f" ] && [ "$(stat -c %s "$f")" != "$antes" ]; do antes="$(stat -c %s "$f")"; sleep 10; done
  [ -f "$f" ] || continue
  nombre="$(basename "$f" .run)"; sello="$(date +%Y%m%d_%H%M%S)"
  tmp="$(mktemp -d "$NSX/trabajo/XXXXXX")"
  # Se trabaja sobre una copia de root: el archivo original no puede cambiarse despues de verificarlo
  mv "$f" "$tmp/paquete.run"; chown root:root "$tmp/paquete.run"
  linea="$(grep -a -n -m1 '^__CARGA__$' "$tmp/paquete.run" | cut -d: -f1)"
  firma="$(head -n "${linea:-1}" "$tmp/paquete.run" | sed -n 's/^#FIRMA://p')"
  if [ -n "$linea" ] && [ -n "$firma" ] \
     && tail -n +$((linea+1)) "$tmp/paquete.run" > "$tmp/carga.tgz" \
     && echo "$firma" | base64 -d > "$tmp/firma.bin" \
     && openssl dgst -sha256 -verify "$NSX/publica.pem" -signature "$tmp/firma.bin" "$tmp/carga.tgz" >/dev/null 2>&1; then
    mkdir "$tmp/paq"; tar -xzf "$tmp/carga.tgz" -C "$tmp/paq"
    cp "$tmp/paquete.run" "$HECHOS/$nombre.run"
    bash "$tmp/paq/instalar.sh" "$tmp/paq" "$CARPETA/$nombre.run"
    mv "$HECHOS/$nombre.run" "$HECHOS/${nombre}_$sello.run" 2>/dev/null
  else
    echo "$(date '+%F %T') El archivo no esta completo o no esta firmado por INSEPET. No se instalo." > "$CARPETA/${nombre}_${sello}_ERROR.txt"
    mv "$tmp/paquete.run" "$HECHOS/${nombre}_${sello}_rechazado.bin"
  fi
  rm -rf "$tmp"
done
