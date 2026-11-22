import os
import platform
import socket
from datetime import datetime, timezone

from flask import Flask, jsonify, render_template_string

app = Flask(__name__)

PAGE = """
<!doctype html>
<html lang="es">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Flask en Azure</title>
  <style>
    body { font-family: system-ui, sans-serif; background: #0f172a; color: #e2e8f0;
           display: grid; place-items: center; min-height: 100vh; margin: 0; padding: 1rem; }
    .card { background: #1e293b; border-radius: 12px; padding: 2rem; max-width: 520px; width: 100%; }
    h1 { margin-top: 0; color: #38bdf8; }
    td { padding: .3rem .8rem .3rem 0; }
    td:first-child { color: #94a3b8; }
  </style>
</head>
<body>
  <div class="card">
    <h1>¡Hola desde Azure!</h1>
    <p>Página servida por Flask, detrás de Nginx, en contenedores Podman.</p>
    <table>
      <tr><td>Contenedor</td><td>{{ hostname }}</td></tr>
      <tr><td>Arquitectura</td><td>{{ arch }}</td></tr>
      <tr><td>Python</td><td>{{ python }}</td></tr>
      <tr><td>Hora (UTC)</td><td>{{ now }}</td></tr>
      <tr><td>Entorno</td><td>{{ env }}</td></tr>
    </table>
  </div>
</body>
</html>
"""


@app.route("/")
def index():
    return render_template_string(
        PAGE,
        hostname=socket.gethostname(),
        arch=platform.machine(),
        python=platform.python_version(),
        now=datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S"),
        env=os.environ.get("APP_ENV", "dev"),
    )


@app.route("/health")
def health():
    return jsonify(status="ok")
