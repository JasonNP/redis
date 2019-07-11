variable "resource_group_name" {
  description = "The name of the resource group in which to create the resources."
  type        = string
}
variable "location" {
  description = "Specifies the region in which to create the resources."
  type        = string
  default     = "eastus2"
}
variable "environment" {
  description = "Specifies the environment in which the resources will be created."
  type        = string
}
variable "redis_name" {
  description = "Specifies the name of the redis cache"
  type        = string
}

variable "capacity" {
  description = "Specifies the name of the redis cache"
  type        = string
}
variable "family" {
  description = "Specifies the name of the redis cache"
  type        = string
}
variable "sku_name" {
  description = "Specifies the name of the redis cache"
  type        = string
}
variable "minimum_tls_version" {
  description = "Specifies the name of the redis cache"
  type        = string
}
