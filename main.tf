# Groupe de ressources - conteneur logique pour toutes les ressources
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

# Stockage Azure Blob Storage

# Compte de stockage
resource "azurerm_storage_account" "stockage" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS" # Réplication locale (moins cher)
}

# Attendre que le stockage soit propagé dans Azure (contournement bug azurerm)
resource "time_sleep" "attendre_stockage" {
  depends_on      = [azurerm_storage_account.stockage]
  create_duration = "30s"
}

# Conteneur pour les fichiers statiques (images, logs, etc.)
resource "azurerm_storage_container" "conteneur" {
  name                  = var.container_name
  storage_account_id    = azurerm_storage_account.stockage.id
  container_access_type = "private" # Accès privé pour la sécurité
  depends_on            = [time_sleep.attendre_stockage]
}

# Réseau virtuel et sous-réseau
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-cloud-projet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Attendre que le réseau virtuel soit propagé dans Azure (contournement bug azurerm)
resource "time_sleep" "attendre_reseau" {
  depends_on      = [azurerm_virtual_network.vnet]
  create_duration = "30s"
}

resource "azurerm_subnet" "subnet" {
  name                 = "subnet-cloud-projet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
  depends_on           = [time_sleep.attendre_reseau]
}

# IP publique pour accéder à la VM
resource "azurerm_public_ip" "ip_publique" {
  name                = "ip-publique-vm"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
}

# Groupe de sécurité réseau (pare-feu)
resource "azurerm_network_security_group" "nsg" {
  name                = "nsg-cloud-projet"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  # Autoriser SSH (port 22)
  security_rule {
    name                       = "autoriser-ssh"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Autoriser le trafic HTTP sur le port 5000 (Flask)
  security_rule {
    name                       = "autoriser-flask"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5000"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Interface réseau de la VM
resource "azurerm_network_interface" "nic" {
  name                = "nic-vm-cloud"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "config-ip-interne"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.ip_publique.id
  }
}

# Associer le NSG à l'interface réseau
resource "azurerm_network_interface_security_group_association" "nsg_assoc" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# Machine virtuelle Ubuntu 24.04
resource "azurerm_linux_virtual_machine" "vm" {
  name                = "vm-flask-cloud"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = var.vm_size
  admin_username      = var.admin_username

  network_interface_ids = [
    azurerm_network_interface.nic.id,
  ]

  # Authentification par clé SSH
  admin_ssh_key {
    username   = var.admin_username
    public_key = file(pathexpand(var.ssh_public_key_path))
  }

  # Image Ubuntu 24.04 LTS
  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  # Disque virtuel
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  # Identité managée pour accéder au Blob Storage sans clé
  identity {
    type = "SystemAssigned"
  }

  # Script d'initialisation : installe Python, Flask, et lance l'application
  custom_data = base64encode(templatefile("${path.module}/cloud-init.yaml", {
    storage_account_name = azurerm_storage_account.stockage.name
    container_name       = var.container_name
    storage_account_key  = azurerm_storage_account.stockage.primary_access_key
    db_host              = azurerm_postgresql_flexible_server.db.fqdn
    db_name              = azurerm_postgresql_flexible_server_database.app_db.name
    db_user              = var.db_admin_login
    db_password          = var.db_admin_password
  }))
}

# Donner à la VM l'accès au Blob Storage via son identité managée
resource "azurerm_role_assignment" "vm_blob_acces" {
  scope                = azurerm_storage_account.stockage.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_linux_virtual_machine.vm.identity[0].principal_id
}

# Base de données PostgreSQL Flexible Server
resource "azurerm_postgresql_flexible_server" "db" {
  name                          = "pg-cloud-projet"
  resource_group_name           = azurerm_resource_group.rg.name
  location                      = azurerm_resource_group.rg.location
  version                       = "16"
  administrator_login           = var.db_admin_login
  administrator_password        = var.db_admin_password
  storage_mb                    = 32768
  sku_name                      = "B_Standard_B1ms"
  zone                          = "1"
  public_network_access_enabled = true
}

# Règle de pare-feu pour autoriser toutes les IP Azure (dont notre VM)
resource "azurerm_postgresql_flexible_server_firewall_rule" "autoriser_azure" {
  name             = "autoriser-services-azure"
  server_id        = azurerm_postgresql_flexible_server.db.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "255.255.255.255"
}

# Base de données pour l'application
resource "azurerm_postgresql_flexible_server_database" "app_db" {
  name      = "flaskdb"
  server_id = azurerm_postgresql_flexible_server.db.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}
