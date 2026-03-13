# Variables

variable "subscription_id" {
  description = "ID de l'abonnement Azure"
  type        = string
}

variable "resource_group_name" {
  description = "Nom du groupe de ressources Azure"
  type        = string
  default     = "rg-cloud-projet"
}

variable "location" {
  description = "Région Azure pour le déploiement"
  type        = string
  default     = "Sweden Central"
}

variable "vm_size" {
  description = "Taille de la machine virtuelle"
  type        = string
  default     = "Standard_B2ats_v2"
}

variable "admin_username" {
  description = "Nom d'utilisateur administrateur de la VM"
  type        = string
  default     = "azureuser"
}

variable "ssh_public_key_path" {
  description = "Chemin vers la clé publique SSH"
  type        = string
  default     = "~/.ssh/id_ed25519.pub" # Mr, changez la clé ssh ici si vous avez une clé RSA au lieu de ED22519: id_rsa
}

variable "storage_account_name" {
  description = "Nom du compte de stockage Azure (doit être unique et en minuscules)"
  type        = string
  default     = "stocloudprojet2026"
}

variable "container_name" {
  description = "Nom du conteneur Blob Storage"
  type        = string
  default     = "fichiers-statiques"
}

variable "db_admin_login" {
  description = "Nom d'utilisateur administrateur de la base de données PostgreSQL"
  type        = string
  default     = "pgadmin"
}

variable "db_admin_password" {
  description = "Mot de passe administrateur de la base de données PostgreSQL"
  type        = string
  sensitive   = true
}
