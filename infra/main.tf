# Generate random resource group name
resource "random_pet" "rg_name" {
  prefix = var.resource_group_name_prefix
}

resource "azurerm_resource_group" "rg" {
  location = var.resource_group_location
  name     = random_pet.rg_name.id
}

resource "random_pet" "azurerm_kubernetes_cluster_name" {
  prefix = "cluster"
}

resource "random_pet" "azurerm_kubernetes_cluster_dns_prefix" {
  prefix = "dns"
}

resource "azurerm_kubernetes_cluster" "k8s" {
  location            = azurerm_resource_group.rg.location
  name                = random_pet.azurerm_kubernetes_cluster_name.id
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = random_pet.azurerm_kubernetes_cluster_dns_prefix.id

  identity {
    type = "SystemAssigned"
  }

  default_node_pool {
    name       = "systempool"
    vm_size    = var.system_vm_size
    node_count = var.system_node_count
    # 注意：这里不设置 priority、eviction_policy 等 Spot 相关属性
  }
  linux_profile {
    admin_username = var.username

    ssh_key {
      key_data = azapi_resource_action.ssh_public_key_gen.output.publicKey
    }
  }
  network_profile {
    network_plugin    = "kubenet"
    load_balancer_sku = "standard"
  }
}
resource "azurerm_kubernetes_cluster_node_pool" "spot_user_pool" {
  count = var.enable_spot_user_pool ? 1 : 0

  name                  = var.spot_user_pool_name
  kubernetes_cluster_id = azurerm_kubernetes_cluster.k8s.id
  vm_size               = var.spot_vm_size
  node_count            = var.spot_node_count
  mode                  = "User"  # 明确为 User 模式
  
  # Spot 实例专属配置
  priority         = "Spot"
  eviction_policy  = "Delete"
  spot_max_price   = -1   # -1 表示按当前 Spot 价格付费

  # 添加 taint 以防止非容忍的 Pod 被调度到此节点池
  node_taints = [
    "kubernetes.azure.com/scalesetpriority=spot:NoSchedule"
  ]

  # 可选：启用自动缩放以适应 Spot 实例的可用性
  auto_scaling_enabled = true
  min_count           = 1
  max_count           = 3

  # 标签（可选）：便于识别和管理
  tags = {
    Environment = "Development"
    Purpose     = "Spot Workloads"
  }
}