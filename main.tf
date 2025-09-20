# Copyright (c) 2024 BB Tech Systems LLC

# Local values derived from VMs that have already been created. These IPs are
# discovered via the Proxmox guest agent after the VMs boot and obtain an IP
# (e.g., via DHCP or a static config baked into the image). They are NOT
# IPs you pre‑assign with Terraform; rather, they are read from the running VMs
# and then reused to configure and bootstrap Talos.
locals {
    # First control plane node IP (used for cluster_endpoint, bootstrap and kubeconfig)
    primary_control_node_ip = proxmox_virtual_environment_vm.talos_control_vm[keys(var.control_nodes)[0]].ipv4_addresses[7][0]

    # All control plane node IPs discovered from the created VMs
    control_node_ips = [for vm in keys(var.control_nodes) : proxmox_virtual_environment_vm.talos_control_vm[vm].ipv4_addresses[7][0]]

    # All worker node IPs discovered from the created VMs
    worker_node_ips = [for vm in keys(var.worker_nodes) : proxmox_virtual_environment_vm.talos_worker_vm[vm].ipv4_addresses[7][0]]

    # Convenience list of every node IP (control + worker)
    node_ips = concat(
        local.control_node_ips,
        local.worker_node_ips
    )
}

resource "proxmox_virtual_environment_download_file" "talos_image" {
    content_type = "iso"
    datastore_id = var.proxmox_iso_datastore
    node_name    = values(var.control_nodes)[0].proxmox_node_name # Use the Proxmox node name from the first control_node
    url          = "https://factory.talos.dev/image/${var.talos_schematic_id}/v${var.talos_version}/metal-${var.talos_arch}.qcow2"
    file_name    = "${var.talos_cluster_name}-talos_linux-${var.talos_schematic_id}-${var.talos_version}-${var.talos_arch}.img"
}

resource "proxmox_virtual_environment_vm" "talos_control_vm" {
    for_each  = var.control_nodes
    name      = each.key
    node_name = each.value.proxmox_node_name # Use the Proxmox node name from the map
    agent {
        enabled = true
    }
    cpu {
        cores = each.value.cores # Use cores from the map
        type  = var.proxmox_vm_type
    }
    memory {
        dedicated = each.value.memory # Use memory from the map
        floating  = each.value.memory # Use memory from the map
    }
    disk {
        datastore_id = each.value.image_datastore # Use image datastore from the map
        file_id      = proxmox_virtual_environment_download_file.talos_image.id
        interface    = "virtio0"
        iothread     = true
        discard      = "on"
        size         = each.value.disk_size # Use disk size from the map
    }
    network_device {
        vlan_id = var.proxmox_network_vlan_id
        bridge  = var.proxmox_network_bridge
    }
    operating_system {
        type = "l26"
    }

  initialization {
    dynamic "ip_config" {
      for_each = (try(each.value.ip_address, null) != null && try(each.value.subnet_mask, null) != null && try(each.value.gateway, null) != null) ? [1] : []
      content {
        ipv4 {
          address = "${each.value.ip_address}/${each.value.subnet_mask}"
          gateway = each.value.gateway
        }
      }
    }

    dynamic "dns" {
      for_each = length(coalescelist(each.value.dns_servers, [])) > 0 ? [1] : []
      content {
        servers = each.value.dns_servers
      }
    }

    # Disable cloud-init user creation (Talos manages this)
    dynamic "user_account" {
      for_each = (try(each.value.ip_address, null) != null && try(each.value.subnet_mask, null) != null && try(each.value.gateway, null) != null) ? [1] : []
      content {
        username = "talos"
        password = "disabled"
      }
    }
  }
}

resource "proxmox_virtual_environment_vm" "talos_worker_vm" {
    for_each  = var.worker_nodes
    name      = each.key
    node_name = each.value.proxmox_node_name # Use the Proxmox node name from the map
    agent {
        enabled = true
    }
    cpu {
        cores = each.value.cores # Use cores from the map
        type  = var.proxmox_vm_type
    }
    memory {
        dedicated = each.value.memory # Use memory from the map
        floating  = each.value.memory # Use memory from the map
    }
    disk {
        datastore_id = each.value.image_datastore # Use image datastore from the map
        file_id      = proxmox_virtual_environment_download_file.talos_image.id
        interface    = "virtio0"
        iothread     = true
        discard      = "on"
        size         = each.value.disk_size # Use disk size from the map
    }
    network_device {
        vlan_id = var.proxmox_network_vlan_id
        bridge  = var.proxmox_network_bridge
    }
    dynamic "disk" {
        for_each = each.value.extra_disks # Now directly access 'extra_disks' from the 'each.value' object
        content {
            datastore_id = disk.value.datastore_id
            file_format  = disk.value.file_format
            file_id      = disk.value.file_id
            interface    = "virtio${disk.key+1}"
            iothread     = true
            discard      = "on"
            size         = disk.value.size
        }
    }
    operating_system {
        type = "l26"
    }
}

resource "talos_machine_secrets" "talos_secrets" {}

data "talos_machine_configuration" "control_mc" {
    cluster_name          = var.talos_cluster_name
    machine_type          = "controlplane"
    # TODO - Should we allow the user to override this?
    # This is a single point of failure but without a proxy or load balancer
    # it is required to be a single point of failure.
    cluster_endpoint      = "https://${local.primary_control_node_ip}:6443"
    machine_secrets       = talos_machine_secrets.talos_secrets.machine_secrets
}

data "talos_machine_configuration" "worker_mc" {
    cluster_name          = var.talos_cluster_name
    machine_type          = "worker"
    # TODO - Should we allow the user to override this?
    # This is a single point of failure but without a proxy or load balancer
    # it is required to be a single point of failure.
    cluster_endpoint      = "https://${local.primary_control_node_ip}:6443"
    machine_secrets       = talos_machine_secrets.talos_secrets.machine_secrets
}

data "talos_client_configuration" "talos_client_config" {
    cluster_name         = var.talos_cluster_name
    client_configuration = talos_machine_secrets.talos_secrets.client_configuration
    endpoints            = local.control_node_ips
    nodes                = local.node_ips
}

resource "talos_machine_configuration_apply" "talos_control_mc_apply" {
    for_each                      = var.control_nodes
    client_configuration          = talos_machine_secrets.talos_secrets.client_configuration
    machine_configuration_input = data.talos_machine_configuration.control_mc.machine_configuration
    node                          = proxmox_virtual_environment_vm.talos_control_vm[each.key].ipv4_addresses[7][0]
    config_patches                = var.control_machine_config_patches
}

resource "talos_machine_configuration_apply" "talos_worker_mc_apply" {
    for_each                      = var.worker_nodes
    client_configuration          = talos_machine_secrets.talos_secrets.client_configuration
    machine_configuration_input = data.talos_machine_configuration.worker_mc.machine_configuration
    node                          = proxmox_virtual_environment_vm.talos_worker_vm[each.key].ipv4_addresses[7][0]
    config_patches                = var.worker_machine_config_patches
}

# You only need to bootstrap 1 control node; we pick the first one.
resource "talos_machine_bootstrap" "talos_bootstrap" {
    node                 = local.primary_control_node_ip
    client_configuration = talos_machine_secrets.talos_secrets.client_configuration
}

resource "talos_cluster_kubeconfig" "talos_kubeconfig" {
    depends_on           = [
        talos_machine_bootstrap.talos_bootstrap
    ]
    client_configuration = talos_machine_secrets.talos_secrets.client_configuration
    node                 = local.primary_control_node_ip
}
