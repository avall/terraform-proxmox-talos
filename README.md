# terraform-proxmox-talos

Terraform module to provision Talos Linux Kubernetes clusters with Proxmox

## Example usage

```bash
export PROXMOX_VE_USERNAME="root@pam"
export PROXMOX_VE_PASSWORD="super-secret"
```

```terraform
# Example terraform.tfvars or directly in main.tf for testing
talos_cluster_name = "my-talos-cluster"
talos_version      = "1.6.0" # Make sure to use a valid Talos version

module "talos" {
  control_nodes = {
    "talos-control-0" = {
      proxmox_node_name = "pve-node-01"
      cores             = 4
      memory            = 8192 # 8 GB
      disk_size         = 64
      image_datastore   = "local-lvm"
      # Optional static IPv4 for this VM (CIDR). If omitted, DHCP is used.
      ipv4              = "10.10.30.230/24"
      # Optional gateway (only used when ipv4 is set)
      ipv4_gateway      = "10.10.30.1"
    },
    "talos-control-1" = {
      proxmox_node_name = "pve-node-02"
      cores             = 2
      memory            = 4096 # 4 GB
      disk_size         = 32
      image_datastore   = "fast-ssd-storage"
    }
  }

  worker_nodes = {
    "talos-worker-0" = {
      proxmox_node_name = "pve-node-01"
      cores             = 4
      memory            = 8192 # 8 GB
      disk_size         = 100
      image_datastore   = "local-lvm"
      # Optional static IPv4 for this VM (CIDR). If omitted, DHCP is used.
      ipv4              = "192.168.50.20/24"
      # Optional gateway (only used when ipv4 is set)
      ipv4_gateway      = "192.168.50.1"
      extra_disks = [ # Additional disk for talos-worker-0
        {
          datastore_id = "nfs-storage"
          size         = 200
          file_format  = "qcow2"
        }
      ]
    },
    "talos-worker-1" = {
      proxmox_node_name = "pve-node-02"
      cores             = 8
      memory            = 16384 # 16 GB
      disk_size         = 200
      image_datastore   = "cephfs-storage"
      # extra_disks is optional, so you can completely omit it if you don't need additional disks
    }
  }
}
```

## FAQ

- What are `control_node_ips`, `worker_node_ips`, and `node_ips`? Are these pre-assigned IPs or IPs discovered after the VMs are created?
  - They are IPs discovered/exposed by the VMs after they have been created and booted. The Proxmox provider reads these addresses through the guest agent (qemu-guest-agent) and exposes them in `ipv4_addresses`. In this module, the IPs are read from those properties of the already-created `proxmox_virtual_environment_vm` resources and then reused to configure Talos (cluster_endpoint, bootstrap, kubeconfig, etc.).
  - In other words: Terraform does not pre-assign these IPs here. They must come from your network (for example, via DHCP or a static configuration baked into the image). Once the VMs obtain their IP, the module reads it and uses it.
  - `node_ips = concat(local.control_node_ips, local.worker_node_ips)` simply builds a list with all IPs (control + workers) so that Talos can target all nodes when needed.

- And what about the `[7][0]` index in `ipv4_addresses[7][0]`?
  - It refers to a specific position within the structure returned by the provider (a list of lists of addresses). Depending on your network/bridge/VLAN setup, the index may vary. If your IP is not being resolved correctly, inspect which positions `ipv4_addresses` returns for your VMs and adjust the index in `main.tf`.

Check out our [blog post](https://bbtechsystems.com/blog/k8s-with-pxe-tf/) for more details on using this module.

Copyright (c) 2024 BB Tech Systems LLC
