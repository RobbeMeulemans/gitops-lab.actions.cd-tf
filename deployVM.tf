terraform {
  backend "azurerm" {
        storage_account_name = "saterraformlabphi"
        container_name = "terraform"
        key = "terraform.tfstate"
        # access_key = "jqC2DtY1aPx4y17KJHk/iFsrgA3t5O6bWowKc1zQ/2TP+UNJuMjmMfbUkIpMR289w6o1PE/cfPwS+AStZKxNnA=="
        access_key = var.ACCESS_KEY
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


provider "azurerm" {
  features {}
 
  subscription_id = var.subscription_id
  client_id       = var.client_id
  client_secret   = var.client_secret
  tenant_id       = var.tenant_id
}

variable "RGName" {
  default = "rgVirtualMachineDemo"
}

variable "VMName" {
  default = "VM1"
}

variable "VMLocation" {
  default = "SwedenCentral"
}

resource "azurerm_resource_group" "RG" {
  name = var.RGName
  location = var.VMLocation
}

variable "vnetaddress" {
  default = "10.10.0.0/16"
}

variable "subnetaddress"{
  default = "10.10.0.0/24"
}

variable "admin_pwd" {
}

resource "azurerm_virtual_network" "VNet" {
    name = "VNet1"
    address_space = [var.vnetaddress]
    location = azurerm_resource_group.RG.location
    resource_group_name = azurerm_resource_group.RG.name
}

resource "azurerm_subnet" "Subnet1" {
    name = "FESubnet"
    address_prefixes = [var.subnetaddress]
    resource_group_name = azurerm_resource_group.RG.name
    virtual_network_name = azurerm_virtual_network.VNet.name
}

resource "azurerm_public_ip" "PublicIP" {
    name = "PublicIP1"
    location = azurerm_resource_group.RG.location
    resource_group_name = azurerm_resource_group.RG.name
    allocation_method = "Static"
}

resource "azurerm_network_security_group" "my_terraform_nsg" {
  name                = "VM_NSG"
  location            = azurerm_resource_group.RG.location
  resource_group_name = azurerm_resource_group.RG.name

  security_rule {
    name                       = "RDP"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "web"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface" "VM_NIC" {
  name                = "VM_NIC"
  location            = azurerm_resource_group.RG.location
  resource_group_name = azurerm_resource_group.RG.name

  ip_configuration {
    name                          = "IPConfig1"
    subnet_id                     = azurerm_subnet.Subnet1.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.PublicIP.id
  }  
}

resource "azurerm_network_interface_security_group_association" "SGNIC" {
  network_interface_id      = azurerm_network_interface.VM_NIC.id
  network_security_group_id = azurerm_network_security_group.my_terraform_nsg.id
}

resource "azurerm_storage_account" "sadiagnostics20250612" {
    name = "sadiagnostics20250612"
    location = azurerm_resource_group.RG.location   
    resource_group_name = azurerm_resource_group.RG.name
    account_tier = "Standard"
    account_replication_type = "LRS"
}

resource "azurerm_windows_virtual_machine" "VM" {
    name = var.VMName
    resource_group_name = azurerm_resource_group.RG.name
    location = azurerm_resource_group.RG.location
    size = "Standard_DS1_v2"
    admin_username = "peter"
    admin_password = "U2U_secret"
    network_interface_ids = [azurerm_network_interface.VM_NIC.id]
    os_disk {
        name                 = "myOsDisk"
        caching              = "ReadWrite"
        storage_account_type = "Premium_LRS"
    }

    source_image_reference {
        publisher = "MicrosoftWindowsServer"
        offer     = "WindowsServer"
        sku       = "2022-datacenter-azure-edition"
        version   = "latest"
    }

    boot_diagnostics {
        storage_account_uri = azurerm_storage_account.sadiagnostics20250612.primary_blob_endpoint
    }
    os_profile {
      computer_name  = "VM1"
      admin_username = "u2uadmin"
      admin_password = var.admin_pwd
    }
}
