terraform {
  backend "remote" {
    organization = "rmOrg"
 
    workspaces {
      name = "AzureDeploy"
    }
  }
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=2.46.0"
    }
  }
}

variable "client_id" {
}
variable "client_secret" {
}
variable "subscription_id" {
}
variable "tenant_id" {
}


variable "resourceGroupName" {
    default = "RG10"
}

variable "vmName" {
    default = "VM10"
}

variable "subscriptionId" {
   type = string
}

variable "vnetAddress" {
    default = "10.10.0.0/16"
}

variable "subnetAddress" {
    default = "10.10.0.0/24"
}

provider "azurerm" {
    features { }
    subscription_id = var.subscriptionId
}
data "azurerm_key_vault" "keyvault" {
    name = "kvels100"
    resource_group_name = "RG1" 
}

data "azurerm_key_vault_secret" "adminpwd" {
    name = "adminpwd"
    key_vault_id = data.azurerm_key_vault.keyvault.id
}

resource "azurerm_resource_group" "RG" {
  name = var.resourceGroupName
  location = "West Europe"
}

resource "azurerm_virtual_network" "VNet" {
  name = "VNet10"
  address_space = [ var.vnetAddress ]
  location = azurerm_resource_group.RG.location
  resource_group_name = azurerm_resource_group.RG.name
}

resource "azurerm_subnet" "Subnet1" {
  name = "FESubnet"
  address_prefixes = [ var.subnetAddress ]
  resource_group_name = azurerm_resource_group.RG.name
  virtual_network_name = azurerm_virtual_network.VNet.name
}

resource "azurerm_public_ip" "Pip1" {
    name = "PipVM10"
    resource_group_name = azurerm_resource_group.RG.name
    location = azurerm_resource_group.RG.location
    allocation_method = "Static"
    sku = "Standard"  
}

resource "azurerm_network_security_group" "NSG1" {
    name = "NsgVM10"
    resource_group_name = azurerm_resource_group.RG.name
    location = azurerm_resource_group.RG.location
}

resource "azurerm_network_security_rule" "RDP" {
  name = "AllowRDP"
  priority = 100
  direction = "Inbound"
  access = "Allow"
  protocol = "Tcp"
  source_port_range = "*"
  destination_port_range = "3389"
  source_address_prefix = "*"
  destination_address_prefix = "*"
  network_security_group_name = azurerm_network_security_group.NSG1.name
  resource_group_name = azurerm_resource_group.RG.name
}

resource "azurerm_network_security_rule" "HTTP" {
  name = "AllowHTTP"
  priority = 101
  direction = "Inbound"
  access = "Allow"
  protocol = "Tcp"
  source_port_range = "*"
  destination_port_range = "80"
  source_address_prefix = "*"
  destination_address_prefix = "*"
  network_security_group_name = azurerm_network_security_group.NSG1.name
  resource_group_name = azurerm_resource_group.RG.name
}

resource "azurerm_network_interface" "NIC1" {
    name = "NicVM10"
    resource_group_name = azurerm_resource_group.RG.name
    location = azurerm_resource_group.RG.location
    ip_configuration {
        name = "ipconfigVM10"
        subnet_id = azurerm_subnet.Subnet1.id
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id = azurerm_public_ip.Pip1.id  
    }
}

resource "azurerm_network_interface_security_group_association" "NsgToNic" {
    network_interface_id = azurerm_network_interface.NIC1.id 
    network_security_group_id = azurerm_network_security_group.NSG1.id 
}

resource "azurerm_virtual_machine" "VM1" {
    name = var.vmName
    resource_group_name = azurerm_resource_group.RG.name
    location = azurerm_resource_group.RG.location
    network_interface_ids = [ azurerm_network_interface.NIC1.id ]
    vm_size = "Standard_D2S_v3"
    delete_os_disk_on_termination = true

    storage_image_reference {
      publisher = "MicrosoftWindowsServer"
      offer = "WindowsServer"
      sku = "2022-Datacenter"
      version = "latest"
    }
    storage_os_disk {
      name = "osdiskVM10"
      caching = "ReadWrite"
      create_option = "FromImage"
      managed_disk_type = "Premium_LRS"
    }

    os_profile {
      computer_name = var.vmName
      admin_username = "u2uadmin"
      admin_password = data.azurerm_key_vault_secret.adminpwd.value
    }

    os_profile_windows_config {
      provision_vm_agent = true
    }
}


