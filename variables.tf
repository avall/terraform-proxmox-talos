# Copyright (c) 2024 BB Tech Systems LLC

variable "proxmox_iso_datastore" {
    description = "Datastore to put the qcow2 image"
    type        = string
    default     = "local"
}

variable "proxmox_image_datastore" {
    description = "Datastore to put the VM hard drive images"
    type        = string
    default     = "local-lvm"
}

variable "proxmox_vm_type" {
    description = "Proxmox emulated CPU type, x86-64-v2-AES recommended"
    type        = string
    default     = "x86-64-v2-AES"
}

variable "proxmox_network_vlan_id" {
    description = "Proxmox network VLAN ID"
    type        = number
    default     = null
}
variable "proxmox_network_bridge" {
  description = "Proxmox network Bridge"
  type = string
  default = "vmbr0"
}

variable "talos_cluster_name" {
    description = "Name of the Talos cluster"
    type        = string
}

variable "talos_schematic_id" {
    # Generate your own at https://factory.talos.dev/
    # This ID has these extensions:
    # qemu-guest-agent (required)
    # If you make your own, ensure this extension is checked.
    # The ID is independent of the image's version and architecture.
    description = "Schematic ID for the Talos cluster"
    type        = string
    default     = "ce4c980550dd2ab1b17bbf2b08801c7eb59418eafe8f279833297925d67c7515"
}

variable "talos_version" {
    description = "Version of Talos to use"
    type        = string
}

variable "talos_arch" {
    description = "Architecture of Talos to use"
    type        = string
    default     = "amd64"
}

# These two variables are maps that control how many control and worker nodes are created
# and what their names and individual configurations are.
# The keys are the Talos node names and the values are objects containing
# the Proxmox node name and specific VM configurations.
# Example:
# control_nodes = {
#    "talos-control-0" = {
#        proxmox_node_name = "proxmox-node-0"
#        cores             = 4
#        memory            = 4096
#        disk_size         = 32
#        image_datastore   = "local-lvm"
#    }
# }
# worker_nodes = {
#    "talos-worker-0" = {
#        proxmox_node_name = "proxmox-node-0"
#        cores             = 4
#        memory            = 4096
#        disk_size         = 100
#        image_datastore   = "local-lvm"
#        extra_disks       = [] # Optional
#    }
# }
variable "control_nodes" {
    description = "Map of Talos control node names to their Proxmox node names and VM configurations"
    type        = map(object({
        proxmox_node_name = string
        cores             = number
        memory            = number
        disk_size         = number
        image_datastore   = string
        ipv4              = optional(string)      # Optional static IPv4 in CIDR format, e.g., "192.168.1.10/24". Use DHCP if omitted.
        ipv4_gateway      = optional(string)      # Optional gateway for the static IPv4, e.g., "192.168.1.1"
    }))
}

variable "worker_nodes" {
    description = "Map of Talos worker node names to their Proxmox node names and VM configurations"
    type        = map(object({
        proxmox_node_name = string
        cores             = number
        memory            = number
        disk_size         = number
        image_datastore   = string
        ipv4              = optional(string)      # Optional static IPv4 in CIDR format, e.g., "192.168.1.20/24". Use DHCP if omitted.
        ipv4_gateway      = optional(string)      # Optional gateway for the static IPv4, e.g., "192.168.1.1"
        extra_disks       = optional(list(object({
            datastore_id = string
            size         = number
            file_format  = optional(string)
            file_id      = optional(string)
        })), [])
    }))
}

variable "control_machine_config_patches" {
    description = "List of YAML patches to apply to the control machine configuration"
    type        = list(string)
    default     = [
<<EOT
machine:
  install:
    disk: "/dev/vda"
EOT
    ]
}

variable "worker_machine_config_patches" {
    description = "List of YAML patches to apply to the worker machine configuration"
    type        = list(string)
    default     = [
<<EOT
machine:
  install:
    disk: "/dev/vda"
EOT
    ]
}
