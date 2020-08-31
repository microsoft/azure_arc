# Configure the Google Provider
provider "google" {
  version     = "3.21"
  credentials = file(var.gcp_credentials_filename)
  project     = var.gcp_project_id
  region      = var.gcp_region
}