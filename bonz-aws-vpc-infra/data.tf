################################################################################
# Data Sources
################################################################################

# Get available AZs in the region
data "aws_availability_zones" "available" {
  state = "available"

  # Exclude Local Zones
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

