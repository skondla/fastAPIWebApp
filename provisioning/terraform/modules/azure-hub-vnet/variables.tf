variable "name" {
  type        = string
  description = "Logical name prefix (e.g. fastapi-hub)."
}

variable "location" {
  type        = string
  description = "Azure region (e.g. eastus2)."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group that owns hub networking. Created by this module."
}

variable "address_space" {
  type        = string
  description = "Hub VNet CIDR. Must be RFC1918 and non-overlapping with AWS/GCP (see _global/network-cidr-plan.md)."
  validation {
    condition     = can(cidrhost(var.address_space, 0))
    error_message = "address_space must be a valid CIDR."
  }
}

variable "gateway_subnet_bits" {
  type        = number
  description = "Newbits for GatewaySubnet (required name). /27 minimum recommended by Microsoft."
  default     = 11
}

variable "firewall_subnet_bits" {
  type        = number
  description = "Newbits for AzureFirewallSubnet (required name). /26 minimum."
  default     = 10
}

variable "workload_subnet_bits" {
  type        = number
  description = "Newbits for workload subnets."
  default     = 4
}

variable "enable_firewall" {
  type        = bool
  description = "Toggle Azure Firewall (Premium). Disable for sandbox; ~$1.25/hr fixed + data."
  default     = true
}

variable "enable_vpn_gateway" {
  type        = bool
  description = "Toggle VPN Gateway (VpnGw2 active-active). Needed for cross-cloud IPsec."
  default     = true
}

variable "vpn_gateway_asn" {
  type        = number
  description = "BGP ASN for the Azure VPN gateway. Default 65515 (Azure recommended). Must differ from AWS/GCP."
  default     = 65515
  validation {
    condition     = var.vpn_gateway_asn >= 64512 && var.vpn_gateway_asn <= 65534
    error_message = "Use a private ASN (64512-65534)."
  }
}

variable "flow_logs_retention_days" {
  type        = number
  description = "NSG/VNet flow log retention. Must be >= 90 days for SOC2/PCI."
  default     = 90
  validation {
    condition     = var.flow_logs_retention_days >= 90
    error_message = "Retention must be >= 90 days."
  }
}

variable "log_analytics_workspace_id" {
  type        = string
  description = "LAW resource ID for flow log + diagnostic settings."
}

variable "network_watcher_resource_group" {
  type        = string
  description = "RG name that holds the regional NetworkWatcher (Azure default: NetworkWatcherRG)."
  default     = "NetworkWatcherRG"
}

variable "flow_logs_storage_account_id" {
  type        = string
  description = "Storage account ID used to persist VNet flow logs (the NSG-flow API writes here)."
}

variable "tags" {
  type        = map(string)
  description = "Standard tag map."
}
