terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.13.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
  use_cli         = true
}

locals {
  unique_ips = toset([for service in var.services : service.properties.ip])
  ip_to_ports = {
    for ip in local.unique_ips :
    ip => [
      for service in var.services :
      service.properties.port
      if service.properties.ip == ip
    ]
  }
  ip_port_pairs = flatten([
    for ip, ports in local.ip_to_ports : [
      for i, port in ports : {
        ip       = ip
        port     = port
        priority = 1000 + i
      }
    ]
  ])
  vm_sizes = {
    for ip in local.unique_ips : ip => (
      anytrue([
        contains([for name, service in var.services : name if service.properties.ip == ip], "mysql"),
        contains([for name, service in var.services : name if service.properties.ip == ip], "mysql-master"),
        contains([for name, service in var.services : name if service.properties.ip == ip], "mysql-slave")
      ]) &&
      anytrue([
        contains([for name, service in var.services : name if service.properties.ip == ip], "spring-petclinic"),
        contains([for name, service in var.services : name if service.properties.ip == ip], "spring-petclinic-1"),
        contains([for name, service in var.services : name if service.properties.ip == ip], "spring-petclinic-2")
      ]) ? "Standard_B2s" : "Standard_B1s"
    )
  }
}

resource "azurerm_resource_group" "petclinic-rg" {
  name     = var.resource_group_name
  location = var.location
}
resource "azurerm_virtual_network" "petclinic-vnet" {
  name                = "petclinic-vnet"
  address_space       = [var.main_vnet_address_space]
  location            = azurerm_resource_group.petclinic-rg.location
  resource_group_name = azurerm_resource_group.petclinic-rg.name
}

resource "azurerm_subnet" "petclinic-default-subnet" {
  name                 = "petclinic-default-subnet"
  virtual_network_name = azurerm_virtual_network.petclinic-vnet.name
  address_prefixes     = [var.subnet_prefixes["default"]]
  resource_group_name  = azurerm_resource_group.petclinic-rg.name
  depends_on           = [azurerm_virtual_network.petclinic-vnet]
}

resource "azurerm_network_security_group" "per_ip_security_group" {
  for_each            = local.unique_ips
  name                = "nsg-${each.value}"
  location            = azurerm_resource_group.petclinic-rg.location
  resource_group_name = azurerm_resource_group.petclinic-rg.name
}

resource "azurerm_network_security_rule" "per_ip_and_port_security_rule" {
  for_each                    = { for pair in local.ip_port_pairs : "${pair.ip}-${pair.port}" => pair }
  name                        = "${each.value.port}-Allow"
  priority                    = each.value.priority
  protocol                    = "Tcp"
  access                      = "Allow"
  direction                   = "Inbound"
  source_address_prefix       = "*"
  source_port_range           = "*"
  destination_address_prefix  = "*"
  destination_port_range      = each.value.port
  network_security_group_name = azurerm_network_security_group.per_ip_security_group[each.value.ip].name
  resource_group_name         = azurerm_resource_group.petclinic-rg.name
}


resource "azurerm_network_security_rule" "per_ip_ssh_security_rule" {
  for_each                    = local.unique_ips
  name                        = "SSHAllow"
  priority                    = 999
  protocol                    = "Tcp"
  access                      = "Allow"
  direction                   = "Inbound"
  source_address_prefix       = each.value == var.services["angular-frontend"].properties.ip ? "*" : var.services["angular-frontend"].properties.ip
  source_port_range           = "*"
  destination_address_prefix  = "*"
  destination_port_range      = 22
  network_security_group_name = azurerm_network_security_group.per_ip_security_group[each.value].name
  resource_group_name         = azurerm_resource_group.petclinic-rg.name
}

resource "azurerm_public_ip" "angular-frontend-ip" {
  name                = "frontend-ip"
  allocation_method   = "Static"
  location            = var.location
  resource_group_name = azurerm_resource_group.petclinic-rg.name
}

resource "azurerm_network_interface" "per_ip_network_interface" {
  for_each            = local.unique_ips
  name                = "${each.value}-nic"
  location            = var.location
  resource_group_name = azurerm_resource_group.petclinic-rg.name
  depends_on          = [azurerm_subnet.petclinic-default-subnet, azurerm_network_security_group.per_ip_security_group]

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.petclinic-default-subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = each.value
    public_ip_address_id          = each.value == var.services["angular-frontend"].properties.ip ? azurerm_public_ip.angular-frontend-ip.id : null
  }
}

resource "azurerm_network_interface_security_group_association" "per_ip_network_interface_nsg_association" {
  for_each                  = local.unique_ips
  network_interface_id      = azurerm_network_interface.per_ip_network_interface[each.value].id
  network_security_group_id = azurerm_network_security_group.per_ip_security_group[each.value].id
}

resource "azurerm_linux_virtual_machine" "service_vm" {
  for_each       = local.unique_ips
  name           = "${each.value}-vm"
  location       = var.location
  size           = local.vm_sizes[each.value]
  admin_username = var.admin_username
  admin_password = var.admin_password

  disable_password_authentication = false

  network_interface_ids = [
    azurerm_network_interface.per_ip_network_interface[each.value].id
  ]

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
  resource_group_name = azurerm_resource_group.petclinic-rg.name
}

output "services_details" {
  value = {
    for name, service in var.services : name => {
      name       = name
      private_ip = service.properties.ip
      public_ip  = name == "angular-frontend" ? azurerm_public_ip.angular-frontend-ip.ip_address : null
      port       = service.properties.port
    }
  }
}