#!/usr/bin/env bash
# Se ejecuta DENTRO de la carpeta ya descomprimida, en la Orange Pi.
# Instala dependencias y deja el servicio systemd armado y corriendo.
# Uso: ./install.sh
set -e
cd "$(dirname "$0")"

SERVICE_NAME="autoservice-page"

echo "== Instalando dependencias (npm install) =="
npm install --omit=dev

SERVICE_USER="$(whoami)"
WORK_DIR="$(pwd)"
NODE_BIN="$(command -v node)"

if [ -z "$NODE_BIN" ]; then
  echo "No se encontró 'node' en el PATH. Instala Node.js antes de continuar."
  exit 1
fi

echo "== Configurando el servicio systemd ($SERVICE_NAME) =="
sudo tee /etc/systemd/system/$SERVICE_NAME.service > /dev/null <<EOF
[Unit]
Description=Panel de autoservicio (INSEPET)
After=network.target

[Service]
Type=simple
User=$SERVICE_USER
WorkingDirectory=$WORK_DIR
ExecStart=$NODE_BIN app.js
Restart=on-failure
RestartSec=5
Environment=NODE_ENV=production
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable $SERVICE_NAME
sudo systemctl restart $SERVICE_NAME

echo
echo "== Listo =="
sudo systemctl status $SERVICE_NAME --no-pager || true
echo
echo "Logs en vivo:        journalctl -u $SERVICE_NAME -f"
echo "Editar config:        nano $WORK_DIR/.env"
echo "Aplicar tras editar:  sudo systemctl restart $SERVICE_NAME"
