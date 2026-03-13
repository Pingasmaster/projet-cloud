# Projet Cloud Computing - Déploiement Automatisé avec Terraform sur Azure

## Description

Ce projet déploie automatiquement une infrastructure cloud sur Azure avec Terraform :
- Une **machine virtuelle Ubuntu 24.04 LTS** avec IP publique
- Un **Azure Blob Storage** pour stocker des fichiers statiques (images, logs, etc.)
- Une **base de données PostgreSQL Flexible Server**
- Une **application Flask** avec API CRUD pour gérer les fichiers et les métadonnées
- Un **service systemd** pour lancer l'application automatiquement au démarrage

## Prérequis

- [Terraform](https://www.terraform.io/downloads) >= 1.0
- [Azure CLI](https://docs.microsoft.com/fr-fr/cli/azure/install-azure-cli)
- Un compte Azure (étudiant ou autre)
- Une paire de clés SSH (`~/.ssh/id_ed25519.pub` ou `~/.ssh/id_rsa.pub`)

## Installation et Utilisation

### 1. Se connecter à Azure

```bash
az login
az account show --query id -o tsv  # Récupérer l'ID de souscription
```

### 2. Configurer les variables

Modifier le fichier `terraform.tfvars` :

```hcl
subscription_id      = "VOTRE_SUBSCRIPTION_ID"
storage_account_name = "stocloudprojet2026"  # Doit être unique sur tout Azure
db_admin_password    = "VotreMotDePasse!"     # Mot de passe PostgreSQL
```

### 3. Déployer l'infrastructure

```bash
terraform init       # Initialiser Terraform et télécharger les providers
terraform plan       # Prévisualiser les changements
terraform apply      # Déployer l'infrastructure (confirmer avec 'yes')
```

> **Note** : Le provider Azure a des problèmes de consistance éventuelle.
> Des ressources `time_sleep` sont intégrées dans la configuration pour gérer ces délais automatiquement.

### 4. Tester l'application

Après le déploiement, Terraform affiche l'IP publique et l'URL de l'application.

```bash
# Vérifier la page d'accueil
curl http://<IP_PUBLIQUE>:5000/

# Envoyer un fichier
curl -X POST -F "fichier=@image.png" http://<IP_PUBLIQUE>:5000/fichiers

# Lister les fichiers
curl http://<IP_PUBLIQUE>:5000/fichiers

# Télécharger un fichier
curl -O http://<IP_PUBLIQUE>:5000/fichiers/image.png

# Supprimer un fichier
curl -X DELETE http://<IP_PUBLIQUE>:5000/fichiers/image.png

# Créer une métadonnée en BDD
curl -X POST -H "Content-Type: application/json" -d '{"cle":"test","valeur":"hello"}' http://<IP_PUBLIQUE>:5000/db

# Lister les métadonnées
curl http://<IP_PUBLIQUE>:5000/db
```

### 5. Se connecter en SSH à la VM

```bash
ssh azureuser@<IP_PUBLIQUE>
```

### 6. Détruire l'infrastructure

```bash
terraform destroy
```

## Structure du Projet

```
.
├── provider.tf          # Configuration du provider Azure
├── main.tf              # Ressources : VM, réseau, stockage, BDD, sécurité
├── variables.tf         # Variables dynamiques
├── outputs.tf           # Sorties (IP, URL, hostname BDD, etc.)
├── terraform.tfvars     # Valeurs sensibles (non commité)
├── cloud-init.yaml      # Script d'initialisation de la VM
├── app/
│   ├── app.py           # Application Flask (CRUD Blob Storage + PostgreSQL)
│   └── requirements.txt # Dépendances Python
├── .gitignore           # Fichiers exclus du dépôt Git
└── README.md            # Ce fichier
```

## Architecture

```
Utilisateur (HTTP/SSH)
        │
        ▼
   IP Publique Azure
        │
        ▼
   ┌─────────────────────┐
   │  VM Ubuntu 24.04    │
   │  ┌───────────────┐  │
   │  │ Flask (port    │  │──────► Azure Blob Storage
   │  │ 5000)          │  │        (fichiers-statiques)
   │  │                │  │──────► PostgreSQL Flexible Server
   │  └───────────────┘  │        (flaskdb)
   └─────────────────────┘
```

## API Endpoints

| Méthode | Route              | Description                          |
|---------|--------------------|--------------------------------------|
| GET     | `/`                | Page d'accueil                       |
| GET     | `/fichiers`        | Lister tous les fichiers             |
| POST    | `/fichiers`        | Envoyer un fichier                   |
| GET     | `/fichiers/<nom>`  | Télécharger un fichier               |
| DELETE  | `/fichiers/<nom>`  | Supprimer un fichier                 |
| GET     | `/db`              | Lister toutes les métadonnées        |
| POST    | `/db`              | Créer une métadonnée                 |
| PUT     | `/db/<clé>`        | Modifier une métadonnée              |
| DELETE  | `/db/<clé>`        | Supprimer une métadonnée             |
