# 00-modules/01-k8s-cluster/talos.tf

# Generate Talos machine secrets
resource "talos_machine_secrets" "cluster_secrets" {
  talos_version = var.talos_version
}

# Control plane configuration
data "talos_machine_configuration" "control_plane" {
  for_each = local.control_plane_nodes

  cluster_name     = var.cluster_name
  cluster_endpoint = "https://${local.cluster_endpoint}:6443" # Используем VIP или DNS-имя
  machine_type     = "controlplane"
  machine_secrets  = talos_machine_secrets.cluster_secrets.machine_secrets

  config_patches = concat([
    yamlencode({
      machine = {
        network = {
          hostname = each.value.name
          interfaces = [{
            deviceSelector = {
              physical = true
            }
            dhcp      = false
            addresses = ["${each.value.ip_address}/${var.network.subnet_mask}"]
            routes = [{
              network = "0.0.0.0/0"
              gateway = var.network.gateway
            }]
          }]
          nameservers = var.network.nameservers
        }
        kubelet = {
          extraArgs = merge(
            var.kubernetes.kubelet_extra_args,
            {
              "node-ip" = each.value.ip_address
            }
          )
        }
        features = var.kubeprism.enabled ? {
          kubePrism = {
            enabled = true
            port    = var.kubeprism.port
          }
        } : {}
      }
      cluster = {
        network = {
          cni = {
            name = var.kubernetes.cni_plugin
          }
          podSubnets     = var.kubernetes.pod_subnets
          serviceSubnets = var.kubernetes.service_subnets
        }
        proxy = {
          disabled = var.kubernetes.kube_proxy_disabled
        }
      }
    })
  ], var.talos_control_plane_patches)
}

# Worker configuration
data "talos_machine_configuration" "worker" {
  for_each = local.worker_nodes

  cluster_name     = var.cluster_name
  cluster_endpoint = "https://${local.cluster_endpoint}:6443"
  machine_type     = "worker"
  machine_secrets  = talos_machine_secrets.cluster_secrets.machine_secrets

  config_patches = concat([
    yamlencode({
      machine = {
        network = {
          hostname = each.value.name
          interfaces = [{
            deviceSelector = {
              physical = true
            }
            dhcp      = false
            addresses = ["${each.value.ip_address}/${var.network.subnet_mask}"]
            routes = [{
              network = "0.0.0.0/0"
              gateway = var.network.gateway
            }]
          }]
          nameservers = var.network.nameservers
        }
        kubelet = {
          extraArgs = merge(
            var.kubernetes.kubelet_extra_args,
            {
              "node-ip" = each.value.ip_address
            },
            length(each.value.labels) > 0 ? {
              "node-labels" = join(",", [
                for k, v in each.value.labels : "${k}=${v}"
              ])
            } : {},
            length(each.value.taints) > 0 ? {
              "register-with-taints" = join(",", [
                for taint in each.value.taints : "${taint.key}=${taint.value}:${taint.effect}"
              ])
            } : {}
          )
        }
        features = var.kubeprism.enabled ? {
          kubePrism = {
            enabled = true
            port    = var.kubeprism.port
          }
        } : {}
      }
      cluster = {
        network = {
          cni = {
            name = var.kubernetes.cni_plugin
          }
        }
      }
    })
  ], var.talos_worker_patches)
}

# Apply configurations
resource "talos_machine_configuration_apply" "control_plane" {
  for_each = local.control_plane_nodes

  client_configuration        = talos_machine_secrets.cluster_secrets.client_configuration
  machine_configuration_input = data.talos_machine_configuration.control_plane[each.key].machine_configuration

  node     = each.value.ip_address
  endpoint = each.value.ip_address

  depends_on = [module.cluster_vms]
}

resource "talos_machine_configuration_apply" "worker" {
  for_each = local.worker_nodes

  client_configuration        = talos_machine_secrets.cluster_secrets.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker[each.key].machine_configuration

  node     = each.value.ip_address
  endpoint = each.value.ip_address

  depends_on = [module.cluster_vms]
}

# Bootstrap the cluster
resource "talos_machine_bootstrap" "cluster" {
  count      = var.bootstrap_enabled ? 1 : 0
  depends_on = [talos_machine_configuration_apply.control_plane]

  client_configuration = talos_machine_secrets.cluster_secrets.client_configuration
  endpoint             = local.control_plane_ips[0]
  node                 = local.control_plane_ips[0]
}

# Generate kubeconfig
resource "talos_cluster_kubeconfig" "kubeconfig" {
  depends_on = [talos_machine_bootstrap.cluster]

  client_configuration = talos_machine_secrets.cluster_secrets.client_configuration
  node                 = local.control_plane_ips[0]

  timeouts = {
    read = "10m"
  }
}
