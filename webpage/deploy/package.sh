#!/usr/bin/env bash
# Compila el cliente y arma UN solo .tar.gz con todo lo necesario para
# desplegar en la Orange Pi (incluye .env e install.sh). Ese único archivo
# se copia a la Pi, se descomprime y se corre install.sh una vez: deja las
# dependencias instaladas y el servicio systemd armado y corriendo.
#
# Uso: bash deploy/package.sh
set -e
cd "$(dirname "$0")/.."

echo "== Compilando el cliente (React) =="
(cd client && npm install --no-audit --no-fund && npm run build)

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

cp app.js package.json package-lock.json .env "$STAGE"/
cp deploy/install.sh "$STAGE"/
chmod +x "$STAGE/install.sh"
cp -r src "$STAGE/src"
rm -rf "$STAGE/src/views"

PKG="autoservicio-deploy.tar.gz"
tar -czf "$PKG" -C "$STAGE" .

echo
echo "Listo: $PKG"
echo "Incluye tu .env real (contraseñas, JWT secret) — transfiérelo solo por"
echo "canales de confianza (scp/USB en tu red local), nunca por internet abierto."
