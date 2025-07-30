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

Check out our [blog post](https://bbtechsystems.com/blog/k8s-with-pxe-tf/) for more details on using this module.

Copyright (c) 2024 BB Tech Systems LLC
