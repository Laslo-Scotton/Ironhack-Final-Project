# --------------------------------------------
# - Resource Group
# --------------------------------------------
resource "azurerm_resource_group" "ls-rg-finalp" {
  name     = "ls-rg-finalp"
  location = "eastus"
}
# --------------------------------------------
# - VN
# --------------------------------------------
resource "azurerm_virtual_network" "ls-vn-finalp" {
  name                = "ls-vn-finalp"
  resource_group_name = azurerm_resource_group.ls-rg-finalp.name
  location            = azurerm_resource_group.ls-rg-finalp.location
  address_space       = ["10.0.0.0/16"]
}
# --------------------------------------------
# - Subnet
# --------------------------------------------
resource "azurerm_subnet" "subnet" {
  name                 = "ls-subnet-finalp"
  resource_group_name  = azurerm_resource_group.ls-rg-finalp.name
  virtual_network_name = azurerm_virtual_network.ls-vn-finalp.name
  address_prefixes     = ["10.0.1.0/24"]
}
# --------------------------------------------
# - NSG
# --------------------------------------------
resource "azurerm_network_security_group" "nsg" {
  name                = "ls-nsg-finalp"
  location            = azurerm_resource_group.ls-rg-finalp.location
  resource_group_name = azurerm_resource_group.ls-rg-finalp.name

  # SSH
  security_rule {
    name                       = "ssh"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.my_public_ip
    destination_address_prefix = "*"
  }

  # SHH Internally
  security_rule {
    name                       = "allow-vnet-ssh"
    priority                   = 150
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  # K8S specifics
  security_rule {
    name                       = "k8s-internal"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = var.dest_port_ranges
    source_address_prefix      = "10.0.0.0/16"
    destination_address_prefix = "*"
  }

  # Allow everything outbound
  security_rule {
    name                       = "allow-all-outbound"
    priority                   = 300
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Potentially need to add the ports for each of the microservices
}
# - Subnet association
resource "azurerm_subnet_network_security_group_association" "nsg-assoc" {
  subnet_id                 = azurerm_subnet.subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}
# - Public Ip for bastion
resource "azurerm_public_ip" "pub-ip" {
  name                = "ls-pip-bastion"
  resource_group_name = azurerm_resource_group.ls-rg-finalp.name
  location            = azurerm_resource_group.ls-rg-finalp.location
  allocation_method   = "Static"
}
# --------------------------------------------
# - NICs (5) 3 nodes 1 mongo 1 bastion
# --------------------------------------------
# Bastion
resource "azurerm_network_interface" "bastion_nic" {
  name                = "ls_nic_bastion"
  resource_group_name = azurerm_resource_group.ls-rg-finalp.name
  location            = azurerm_resource_group.ls-rg-finalp.location

  ip_configuration {
    name                          = "ls-bastion-ipconfig"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pub-ip.id
  }
}
# NIC-Nodes (1) Master
resource "azurerm_network_interface" "node1_nic" {
  name                = "ls_nic_node1"
  resource_group_name = azurerm_resource_group.ls-rg-finalp.name
  location            = azurerm_resource_group.ls-rg-finalp.location

  ip_configuration {
    name                          = "ls-node1-ipconfig"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}
# NIC-Nodes (2)
resource "azurerm_network_interface" "node2_nic" {
  name                = "ls_nic_node2"
  resource_group_name = azurerm_resource_group.ls-rg-finalp.name
  location            = azurerm_resource_group.ls-rg-finalp.location

  ip_configuration {
    name                          = "ls-node2-ipconfig"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}
# NIC-Nodes (3)
resource "azurerm_network_interface" "node3_nic" {
  name                = "ls_nic_node3"
  resource_group_name = azurerm_resource_group.ls-rg-finalp.name
  location            = azurerm_resource_group.ls-rg-finalp.location

  ip_configuration {
    name                          = "ls-node3-ipconfig"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}
# NIC-DB 
resource "azurerm_network_interface" "db_nic" {
  name                = "ls_nic_db"
  resource_group_name = azurerm_resource_group.ls-rg-finalp.name
  location            = azurerm_resource_group.ls-rg-finalp.location

  ip_configuration {
    name                          = "ls-db-ipconfig"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}
# --------------------------------------------
# - create VMs (5) 3 K8s 1 Mongo 1 bastion
# --------------------------------------------
# Bastion VM
resource "azurerm_linux_virtual_machine" "vm_bastion" {
  name                = "ls-bastion-finalp"
  resource_group_name = azurerm_resource_group.ls-rg-finalp.name
  location            = azurerm_resource_group.ls-rg-finalp.location
  size                = "Standard_B1s"

  admin_username                  = var.admin_username
  disable_password_authentication = true #check if needed

  network_interface_ids = [
    azurerm_network_interface.bastion_nic.id
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(var.ssh_public_key_path)
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}
# Master node
resource "azurerm_linux_virtual_machine" "vm_master" {
  name                = "ls-master-finalp"
  resource_group_name = azurerm_resource_group.ls-rg-finalp.name
  location            = azurerm_resource_group.ls-rg-finalp.location
  size                = "Standard_B2s"

  admin_username                  = var.admin_username
  disable_password_authentication = true #check if needed

  network_interface_ids = [
    azurerm_network_interface.node1_nic.id
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(var.ssh_public_key_path)
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}
# Worker Node (1)
resource "azurerm_linux_virtual_machine" "vm_worker1" {
  name                = "ls-worker1-finalp"
  resource_group_name = azurerm_resource_group.ls-rg-finalp.name
  location            = azurerm_resource_group.ls-rg-finalp.location
  size                = "Standard_B2s"

  admin_username                  = var.admin_username
  disable_password_authentication = true #check if needed

  network_interface_ids = [
    azurerm_network_interface.node2_nic.id
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(var.ssh_public_key_path)
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}
# Worker Node (2)
resource "azurerm_linux_virtual_machine" "vm_worker2" {
  name                = "ls-worker2-finalp"
  resource_group_name = azurerm_resource_group.ls-rg-finalp.name
  location            = azurerm_resource_group.ls-rg-finalp.location
  size                = "Standard_B2s"

  admin_username                  = var.admin_username
  disable_password_authentication = true #check if needed

  network_interface_ids = [
    azurerm_network_interface.node3_nic.id
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(var.ssh_public_key_path)
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}
# DB VM
resource "azurerm_linux_virtual_machine" "vm_db" {
  name                = "ls-db-finalp"
  resource_group_name = azurerm_resource_group.ls-rg-finalp.name
  location            = azurerm_resource_group.ls-rg-finalp.location
  size                = "Standard_B2s"

  admin_username                  = var.admin_username
  disable_password_authentication = true #check if needed

  network_interface_ids = [
    azurerm_network_interface.db_nic.id
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(var.ssh_public_key_path)
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}