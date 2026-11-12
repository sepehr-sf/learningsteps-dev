
variable "resource_group_name" {
  description = "Existing Azure Resource Group"
  type        = string
  default     = "rg-learningsteps-dev"
}

variable "location" {
  description = "Azure deployment region"
  type        = string
  default     = "westeurope"
}

variable "vnet_name" {
  description = "Virtual Network name"
  type        = string
  default     = "vnet-learningsteps-dev"
}

variable "vnet_address_space" {
  description = "Virtual Network address space"
  type        = list(string)
  default     = ["10.10.0.0/16"]
}

variable "aks_subnet_name" {
  description = "AKS subnet name"
  type        = string
  default     = "snet-aks"
}

variable "aks_subnet_address_prefix" {
  description = "AKS subnet address range"
  type        = string
  default     = "10.10.1.0/24"
}

variable "database_subnet_name" {
  description = "PostgreSQL delegated subnet name"
  type        = string
  default     = "snet-database"
}

variable "database_subnet_address_prefix" {
  description = "Database subnet address range"
  type        = string
  default     = "10.10.2.0/24"
}

variable "aks_name" {
  description = "AKS cluster name"
  type        = string
  default     = "aks-learningsteps-dev"
}

variable "aks_node_count" {
  description = "Number of AKS nodes"
  type        = number
  default     = 1
}

variable "aks_node_vm_size" {
  description = "AKS node virtual machine size"
  type        = string
  default     = "Standard_D2s_v6"
}

variable "postgres_server_name" {
  description = "Globally unique PostgreSQL server name"
  type        = string
}

variable "postgres_admin_username" {
  description = "PostgreSQL administrator username"
  type        = string
  default     = "learningstepsadmin"
}

variable "postgres_admin_password" {
  description = "PostgreSQL administrator password"
  type        = string
  sensitive   = true
}

variable "key_vault_name" {
  description = "Globally unique Azure Key Vault name"
  type        = string
}

variable "postgres_database_name" {
  description = "LearningSteps database name"
  type        = string
  default     = "learning_journal"
}