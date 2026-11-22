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
ssh "${HOST}" bash -s <<'EOF'
set -euo pipefail
podman build -q -t localhost/flask-app:latest ~/app/flask
podman build -q -t localhost/web-nginx:latest ~/app/nginx
mkdir -p ~/.config/containers/systemd
cp ~/app/web.kube ~/.config/containers/systemd/web.kube
systemctl --user daemon-reload
systemctl --user restart web.service
systemctl --user --no-pager status web.service | head -5
for i in $(seq 1 15); do
  curl -fsS http://localhost/health && echo && exit 0
  sleep 2
done
echo "La app no respondió en /health" >&2
exit 1
EOF

echo ">> Listo: http://${IP}"
