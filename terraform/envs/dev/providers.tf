provider "aws" {
  region              = var.region
  allowed_account_ids = var.allowed_account_ids
  default_tags {
    tags = {
      Platform    = var.platform_name
      Environment = "dev"
      ManagedBy   = "terraform"
    }
  }
}
