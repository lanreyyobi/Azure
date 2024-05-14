# https://azure.microsoft.com/en-us
# Log into your azure subscription by running the command $az login
#1. Terraform block
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.0.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

#2. Configure the Microsoft Azure Provider
provider "azurerm" {
  #skip_provider_registration = true # This is only required when the User, Service Principal, or Identity running Terraform lacks the permissions to register Azure Resource Providers.
  features {}
}

#3. Create a resource group
resource "azurerm_resource_group" "my-test" {
  name     = "devops"
  location = "East US"

  tags = {
    ManagedBy = "Terraform"
  }
}
#4. Create a network
resource "azurerm_virtual_network" "main" {
  name                = "my-network"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.my-test.location
  resource_group_name = azurerm_resource_group.my-test.name
}

#5. Create a subnet
resource "azurerm_subnet" "internal" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.my-test.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]
}

#6. Create a network interface
resource "azurerm_network_interface" "main" {
  name                = "my-nic"
  location            = azurerm_resource_group.my-test.location
  resource_group_name = azurerm_resource_group.my-test.name

  ip_configuration {
    name                          = "test-configuration1"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = azurerm_public_ip.example.id
  }
}

#7. Create a virtual machine
resource "azurerm_linux_virtual_machine" "my-linux-vm" {
  name                = "example-machine"
  resource_group_name = azurerm_resource_group.my-test.name
  location            = azurerm_resource_group.my-test.location
  size                = "Standard_F2"
  admin_username      = "adminuser"
  network_interface_ids = [
    azurerm_network_interface.main.id,
  ]

  custom_data = filebase64("customdata.tpl")

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts"
    version   = "latest"
  }

  provisioner "local-exec" {
    command = templatefile("${var.os}-ssh-script.tpl", {
      hostname = self.public_ip_address,
      user = "adminuser",
      identityfile = "~/.ssh/id_rsa"
    } )
    interpreter = var.os == "windows" ? ["powershell", "-Command"] : ["bash", "-c"]
  }
}

#8. Create an IP
resource "azurerm_public_ip" "example" {
  name                = "acceptanceTestPublicIp1"
  resource_group_name = azurerm_resource_group.my-test.name
  location            = azurerm_resource_group.my-test.location
  allocation_method   = "Dynamic"

  tags = {
    environment = "Production"
  }
}

#9. Create an ssh public key
resource "azurerm_ssh_public_key" "my-key" {
  name                = "my-key"
  resource_group_name = azurerm_resource_group.my-test.name
  location            = azurerm_resource_group.my-test.location
  public_key          = file("~/.ssh/id_rsa.pub")
}

variable "os" {
  type = string
}