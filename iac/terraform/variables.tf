# Auth
variable "ssh_public_key_path" {
  type    = string
  default = "~/.ssh/azure_vm_key.pub"
}

variable "admin_username" {
  default = "azureuser"
}

# Network Security Groups
variable "dest_port_ranges" {
  type    = list(string)
  default = ["6443", "10250", "10257", "10259", "2379-2380"]
}

variable "my_public_ip" {
  default = "176.3.47.205/32"
}
