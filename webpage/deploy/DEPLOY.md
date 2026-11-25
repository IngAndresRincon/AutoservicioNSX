# Desplegar en la Orange Pi

Un solo comprimido, un solo comando en la Pi. Node.js ya está instalado ahí,
así que no hace falta instalar nada de eso.

## 0. Encontrar la Orange Pi en la red y habilitar SSH

En la Orange Pi (con teclado/pantalla, o por HDMI):

```bash
ip addr        # busca la IP en eth0/wlan0, algo como 192.168.x.x
sudo systemctl enable --now ssh   # por si no está habilitado
```

Anota esa IP y el usuario con el que inicias sesión ahí (ej. `orangepi`).

Desde tu PC (Git Bash), prueba la conexión:

```bash
ssh usuario@IP_DE_LA_PI
```

Si conecta, sal con `exit`.

## 1. Primera instalación

### En tu PC

```bash
bash deploy/package.sh
```

Esto compila el cliente de React y genera **un solo archivo**,
`autoservicio-deploy.tar.gz`, con todo adentro: `app.js`, `package.json`,
`src/` (con el build de React ya listo), tu `.env` real, y un script
`install.sh`.

⚠️ Como lleva tu `.env` real (contraseñas, JWT secret), pásalo solo por tu
red local (scp/USB) — nunca lo subas a un sitio público.

Cópialo a la Pi:

```bash
scp autoservicio-deploy.tar.gz usuario@IP_DE_LA_PI:~/
```

### En la Pi

```bash
ssh usuario@IP_DE_LA_PI

mkdir -p ~/autoservicio
tar -xzf autoservicio-deploy.tar.gz -C ~/autoservicio
cd ~/autoservicio
chmod +x install.sh
./install.sh
```

`install.sh` hace todo lo demás solo:

- Instala las dependencias (`npm install --omit=dev` — todas son JS puro,
  no necesitan compilar nada nativo, así que funciona igual de simple que
  en tu PC).
- Arma el servicio systemd (`autoservicio`) usando automáticamente tu
  usuario y la ruta donde quedó la carpeta — no hay que editar nada a mano.
- Lo deja **habilitado en el arranque** y **corriendo ya mismo**, con
  reinicio automático si llegara a caerse.

Al final imprime el estado del servicio. Si dice `active (running)`, ya
está.

## 2. Verificar

Desde otro equipo de la misma red:

```
http://IP_DE_LA_PI:5001/api/nsx-autoservice/page/index
```

Si no carga, revisa el firewall de la Pi:

```bash
sudo ufw allow 5001/tcp
```

## 3. Editar el `.env` más adelante (sin redesplegar nada)

```bash
ssh usuario@IP_DE_LA_PI
nano ~/autoservicio/.env
sudo systemctl restart autoservicio
```

Listo — no hace falta tocar tu PC ni volver a copiar nada para un simple
cambio de configuración.

---

## Actualizar después de un cambio de código

**Importante:** al actualizar, el `.env` de la Pi (el que quizás ya editaste
a mano) **no se toca** — se excluye a propósito de la extracción para no
pisar tus cambios.

### En tu PC

```bash
bash deploy/package.sh
scp autoservicio-deploy.tar.gz usuario@IP_DE_LA_PI:~/
```

### En la Pi

```bash
ssh usuario@IP_DE_LA_PI
tar -xzf autoservicio-deploy.tar.gz -C ~/autoservicio --exclude='.env'
cd ~/autoservicio
./install.sh
```

`install.sh` reinstala dependencias si cambiaron, deja el servicio al día y
lo reinicia. Tu `.env` de la Pi queda exactamente como lo dejaste.

Si alguna vez quieres reemplazar también el `.env` de la Pi por el de tu
PC (por ejemplo, cambiaste la IP de Postgres en tu proyecto local), quita el
`--exclude='.env'` de ese comando una sola vez.
