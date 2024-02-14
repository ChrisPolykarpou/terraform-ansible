terraform {
  required_providers {
    hcloud = {
      source = "hetznercloud/hcloud"
    }
  }
  required_version = ">= 0.13"

  # Configure terraform to use s3 minio
  backend "s3" {
    bucket = "terraform"
    key = "staging/terraform.tfstate"
    endpoints = {
        s3 = "https://cdn.dealer.com.cy"   # Minio endpoint
    }

    access_key = "MINIO_ACCESS_KEY"
    secret_key = "MINIO_SECRET_KEY"

    region = "main"
    skip_requesting_account_id = true
    skip_credentials_validation = true
    skip_metadata_api_check = true
    skip_region_validation = true
    use_path_style = true
  }
}