variable "services" {
  type = map(object({
    properties = object({
      ip   = string
      port = number
    })
  }))
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "subscription_id" {
  type = string
}

variable "subnet_prefixes" {
  type        = map(string)
  description = "Address prefixes for subnets"
}

variable "main_vnet_address_space" {
  type = string
}

variable "admin_username" {
  type        = string
  description = "Administrator username for VMs"
}

variable "admin_password" {
  type        = string
  description = "Administrator password for VMs"
}
