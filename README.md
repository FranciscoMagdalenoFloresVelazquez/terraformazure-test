# TerraformAzure-test

Despliegue de una máquina virtual Linux en **Azure** con **Terraform**, configurada con **cloud-init**, que sirve una página web **Flask** detrás de **Nginx** (HTTPS) en contenedores **Podman** rootless.

Pensado para la **cuenta gratuita de Azure**: usa un tamaño de VM y un disco incluidos en los servicios gratuitos.

## Arquitectura

```
Navegador ──► Azure NSG (22, 80, 443 solo desde tu IP)
                    │
                    ▼
   IP pública ──► VM Ubuntu 24.04 ARM (Standard_B2pts_v2)
                    │   cloud-init: Podman + ajustes del sistema
                    ▼
               Pod "web" (Podman rootless, arranque con systemd/Quadlet)
                 ├─ nginx : 80 → redirige a 443 · 443 TLS → proxy a 127.0.0.1:8000
                 └─ flask : Gunicorn + Flask (solo accesible dentro del pod)
```

| Capa | Herramienta | Qué hace |
|---|---|---|
| Infraestructura | Terraform | Grupo de recursos, red virtual, subred, IP pública, NSG, NIC y VM |
| Sistema operativo | cloud-init (vía `custom_data`) | Instala Podman, permite puertos 80/443 sin root, activa *linger* |
| Aplicación | `app/deploy.sh` | Copia la app, genera el certificado, construye imágenes y levanta el pod |

## Estructura

```
.
├── providers.tf        # Provider azurerm (usa la sesión de az login)
├── variables.tf        # Variables del proyecto
├── main.tf             # Recursos de Azure
├── outputs.tf          # IP pública, URL y comando SSH
├── cloud-init.yaml     # Configuración de la VM en el primer arranque
└── app/
    ├── deploy.sh       # Despliegue de la app en la VM (se ejecuta desde tu PC)
    ├── pod.yaml        # Pod con los contenedores flask + nginx
    ├── web.kube        # Quadlet: crea web.service en systemd
    ├── flask/          # App Flask y su Containerfile
    └── nginx/          # Configuración de Nginx (HTTPS) y su Containerfile
```

## Requisitos

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) con sesión iniciada (`az login`)
- Una clave SSH en `~/.ssh/id_ed25519` (`ssh-keygen -t ed25519`)
- `rsync` y `ssh` en tu equipo

## Configuración

Crea un archivo `terraform.tfvars` en la raíz (está en `.gitignore`, no se sube):

```hcl
subscription_id  = "00000000-0000-0000-0000-000000000000"
allowed_ssh_cidr = "TU.IP.PUBLICA/32"
allowed_web_cidr = "TU.IP.PUBLICA/32"
```

O genéralo automáticamente:

```bash
cat > terraform.tfvars <<EOF
subscription_id  = "$(az account show --query id -o tsv)"
allowed_ssh_cidr = "$(curl -4 -s https://api.ipify.org)/32"
allowed_web_cidr = "$(curl -4 -s https://api.ipify.org)/32"
EOF
```

### Variables

| Variable | Por defecto | Descripción |
|---|---|---|
| `subscription_id` | — (obligatoria) | ID de la suscripción de Azure |
| `allowed_ssh_cidr` | — (obligatoria) | IP permitida para SSH (22) |
| `allowed_web_cidr` | — (obligatoria) | IP permitida para HTTP/HTTPS (80/443). `"*"` para todo internet |
| `location` | `westus2` | Región de Azure |
| `prefix` | `tfazure-test` | Prefijo de los nombres de recursos |
| `vm_size` | `Standard_B2pts_v2` | Tamaño de la VM (ARM, incluido en la cuenta gratuita) |
| `image_sku` | `server-arm64` | Ubuntu 24.04: `server` (x64) o `server-arm64` (ARM) |
| `admin_username` | `azureuser` | Usuario administrador de la VM |
| `ssh_public_key_path` | `~/.ssh/id_ed25519.pub` | Clave pública SSH |

## Uso

### Desplegar

```bash
terraform init
terraform plan -out=tfplan     # revisa qué se va a crear
terraform apply tfplan         # crea la infraestructura (~2 min)
./app/deploy.sh                # despliega la app (espera a cloud-init)
```

Al terminar, `terraform output` muestra:

```
public_ip   = "x.x.x.x"
ssh_command = "ssh azureuser@x.x.x.x"
web_url     = "https://x.x.x.x"
```

### Actualizar la app

Edita los archivos en `app/` y vuelve a ejecutar:

```bash
./app/deploy.sh
```

### Conectarse a la VM

```bash
ssh azureuser@$(terraform output -raw public_ip)

podman ps                       # contenedores
podman logs web-flask           # logs de Flask
systemctl --user status web     # servicio del pod
```

### Destruir

```bash
terraform destroy
```

Borra todos los recursos de Azure. Para recrearlo: `terraform apply` + `./app/deploy.sh`.

## Seguridad

- Acceso SSH **solo con clave**, sin contraseña.
- NSG limitado a tu IP en los puertos 22, 80 y 443.
- Contenedores **rootless**; Flask no se expone fuera del pod.
- El certificado TLS se genera **en la VM** (`~/certs`) y se monta en Nginx; no va en las imágenes ni en Git.
- `terraform.tfvars` y `terraform.tfstate` están excluidos de Git. **Nunca subas el tfstate**: guarda los valores en texto plano.

## Costos (cuenta gratuita)

| Recurso | Costo |
|---|---|
| VM `Standard_B2pts_v2` | Incluida en las 750 h/mes de la cuenta gratuita (12 meses) |
| Disco Premium SSD P6 de 64 GB | Incluido en la cuenta gratuita |
| IP pública Standard estática | ≈ USD 3.65/mes mientras exista (aunque la VM esté apagada) |

Los servicios gratuitos pueden cambiar; revísalos en el portal (*Free services*). Ejecuta `terraform destroy` cuando no la uses.

## Notas y solución de problemas

- **Aviso de certificado en el navegador**: es autofirmado (no hay dominio). La conexión está cifrada; acepta el aviso en *Avanzado → Continuar*. Cambia cada vez que se recrea la VM.
- **`ERR_CONNECTION_TIMED_OUT`**: tu IP pública cambió. Actualiza `terraform.tfvars` y ejecuta `terraform apply` (solo modifica el NSG).
- **`REMOTE HOST IDENTIFICATION HAS CHANGED`** al hacer SSH: la VM se recreó con la misma IP. Ejecuta `ssh-keygen -R <IP>`.
- **Cambiar `cloud-init.yaml` recrea la VM** (`custom_data` fuerza el reemplazo). La IP pública no cambia; vuelve a ejecutar `./app/deploy.sh`.
- **Los datos no persisten**: todo vive en el disco de la VM y se pierde con `terraform destroy`.
