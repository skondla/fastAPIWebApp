terraform {
  required_version = ">= 1.5.0"

  # Megaport provider is intentionally NOT declared here. The schema differs
  # significantly between v0.x and v1.x — pick one and declare it in the
  # caller's versions.tf alongside the real megaport_mcr / megaport_vxc
  # resources. See README for examples.
}
