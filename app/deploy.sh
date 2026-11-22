#!/usr/bin/env bash
# Copia la app a la VM, construye las imágenes y (re)inicia el pod.
# Uso: ./app/deploy.sh            (toma la IP de "terraform output")
set -euo pipefail

cd "$(dirname "$0")/.."
IP="${1:-$(terraform output -raw public_ip)}"
HOST="azureuser@${IP}"

echo ">> Copiando archivos a ${HOST}"
rsync -az --delete app/ "${HOST}:app/"

echo ">> Construyendo imágenes y reiniciando el pod"
ssh "${HOST}" bash -s -- "${IP}" <<'EOF'
set -euo pipefail
IP="$1"

# Certificado autofirmado para la IP pública. Se (re)genera si no existe
# o si la IP cambió (por ejemplo, tras un destroy + apply).
mkdir -p ~/certs && chmod 700 ~/certs
if [ ! -f ~/certs/tls.crt ] || [ "$(cat ~/certs/ip 2>/dev/null)" != "$IP" ]; then
  echo ">> Generando certificado autofirmado para ${IP}"
  openssl req -x509 -newkey rsa:2048 -nodes -days 365 \
    -subj "/CN=${IP}" -addext "subjectAltName=IP:${IP}" \
    -keyout ~/certs/tls.key -out ~/certs/tls.crt 2>/dev/null
  # La clave solo la lee azureuser (que es "root" dentro del contenedor rootless)
  chmod 600 ~/certs/tls.key && chmod 644 ~/certs/tls.crt
  echo "$IP" > ~/certs/ip
fi

podman build -q -t localhost/flask-app:latest ~/app/flask
podman build -q -t localhost/web-nginx:latest ~/app/nginx
mkdir -p ~/.config/containers/systemd
cp ~/app/web.kube ~/.config/containers/systemd/web.kube
systemctl --user daemon-reload
systemctl --user restart web.service
echo "web.service: $(systemctl --user is-active web.service)"
for i in $(seq 1 15); do
  curl -fsSk https://localhost/health && echo && exit 0
  sleep 2
done
echo "La app no respondió en /health" >&2
exit 1
EOF

echo ">> Listo: https://${IP}"
