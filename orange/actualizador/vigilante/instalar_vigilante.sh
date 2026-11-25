#!/bin/bash
# Deja el servicio que instala solo cualquier .run firmado que aparezca en <BASE>/actualizar
set -e
PAQ="$1"; BASE="$2"; DUENO="$3"
NSX=/opt/nsx
mkdir -p "$NSX" "$BASE/actualizar/procesados"
chown "$DUENO": "$BASE/actualizar" "$BASE/actualizar/procesados"
install -m 755 "$PAQ/vigilante/vigilante.sh" "$NSX/vigilante.sh"
install -m 644 "$PAQ/vigilante/publica.pem" "$NSX/publica.pem"

cat > /etc/systemd/system/insepet-actualizador.service <<EOF
[Unit]
Description=Instalador automatico del autoservicio INSEPET

[Service]
Type=oneshot
ExecStart=$NSX/vigilante.sh $BASE/actualizar
TimeoutStartSec=900
EOF
cat > /etc/systemd/system/insepet-actualizador.path <<EOF
[Unit]
Description=Vigila la carpeta de actualizaciones INSEPET

[Path]
PathExistsGlob=$BASE/actualizar/*.run

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable insepet-actualizador.path >/dev/null 2>&1
# Si se esta instalando desde el propio vigilante, no se reinicia
systemctl is-active -q insepet-actualizador.path || systemctl start insepet-actualizador.path
