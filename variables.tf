variable "subscription_id" {
  description = "ID de la suscripción de Azure (az account show --query id -o tsv)"
  type        = string
}

variable "location" {
  description = "Región de Azure donde se crean los recursos"
  type        = string
  default     = "westus2"
}

variable "prefix" {
  description = "Prefijo para nombrar los recursos"
  type        = string
  default     = "tfazure-test"
}

variable "vm_size" {
  description = "Tamaño de la VM (incluido en la cuenta gratuita: B1s, B2pts_v2, B2ats_v2)"
  type        = string
  default     = "Standard_B2pts_v2"
}

variable "image_sku" {
  description = "SKU de Ubuntu 24.04: 'server' para x64, 'server-arm64' para tamaños ARM (B2pts_v2)"
  type        = string
  default     = "server-arm64"
}

variable "admin_username" {
  description = "Usuario administrador de la VM"
  type        = string
  default     = "azureuser"
}

variable "ssh_public_key_path" {
  description = "Ruta a la clave SSH pública"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "allowed_ssh_cidr" {
  description = "IP pública desde la que se permite SSH, en formato CIDR (ej. 1.2.3.4/32)"
  type        = string
}
