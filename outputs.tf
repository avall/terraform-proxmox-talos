# Copyright (c) 2024 BB Tech Systems LLC

output "talos_config" {
    description = "Talos configuration file"
    value       = data.talos_client_configuration.talos_client_config.talos_config
    sensitive   = true
}

output "kubeconfig" {
    description = "Kubeconfig file"
    value       = talos_cluster_kubeconfig.talos_kubeconfig.kubeconfig_raw
    sensitive   = true
}
