variable "resource_group_location" {
  type        = string
  default     = "swedencentral"
  description = "Location of the resource group."
}

variable "resource_group_name_prefix" {
  type        = string
  default     = "rg"
  description = "Prefix of the resource group name that's combined with a random ID so name is unique in your Azure subscription."
}

variable "node_count" {
  type        = number
  description = "The initial quantity of nodes for the node pool."
  default     = 3
}

variable "msi_id" {
  type        = string
  description = "The Managed Service Identity ID. Set this value if you're running this example using Managed Identity as the authentication method."
  default     = null
}

variable "username" {
  type        = string
  description = "The admin username for the new cluster."
  default     = "azureadmin"
}
variable "vm_size" {
  type        = string
  description = "The size of the virtual machines in the node pool."
  default     = "Standard_D2s_v3"   # 默认使用一个较通用的规格
}


variable "system_node_count" {
  type        = number
  description = "Number of nodes in the system node pool (stable, non-Spot)."
  default     = 1   # 开发环境 1 个节点足以运行系统组件
}

variable "system_vm_size" {
  type        = string
  description = "VM size for the system node pool."
  default     = "Standard_D2s_v3"  # 在 swedencentral 可用的稳定规格
}

# 是否启用 Spot 用户节点池（仅开发环境启用）
variable "enable_spot_user_pool" {
  type        = bool
  description = "Enable a secondary Spot node pool for cost-effective dev workloads."
  default     = false
}

variable "spot_user_pool_name" {
  type        = string
  description = "Name of the Spot user node pool."
  default     = "spotdev"
}

variable "spot_vm_size" {
  type        = string
  description = "VM size for the Spot user node pool."
  default     = "Standard_B2s_v2"   # 便宜且可用
}

variable "spot_node_count" {
  type        = number
  description = "Initial node count for the Spot user pool."
  default     = 2
}

# variable "ssh_public_key" {
#   type        = string
#   description = "The SSH public key to use for the new cluster."
#   default     = null
# }