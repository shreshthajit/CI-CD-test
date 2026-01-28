terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# 1. Create the Artifact Registry (Docker Repository)
resource "google_artifact_registry_repository" "my_repo" {
  location      = var.region
  repository_id = "python-backend-repo"
  description   = "Docker repository for python backend"
  format        = "DOCKER"
}

# 2. Create a VPC Network (Default is fine, but we create a firewall rule)
resource "google_compute_firewall" "allow_http" {
  name    = "allow-http-8080"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["8080"]
  }

  source_ranges = ["0.0.0.0/0"]
}

# 3. Create the Compute Instance (VM)
resource "google_compute_instance" "vm_instance" {
  name         = "python-backend-vm"
  machine_type = "e2-medium"
  zone         = "${var.region}-a" # Simple zone mapping

  boot_disk {
    initialize_params {
      image = "projects/debian-cloud/global/images/family/debian-11"
    }
  }

  # Install Docker on the VM using a startup script
  metadata = {
    startup-script = <<-EOF
                  #!/bin/bash
                  apt-get update
                  apt-get install -y docker.io
                  usermod -aG docker ${var.ssh_user}
                  systemctl start docker
                  EOF
  }

  network_interface {
    network = "default"
    access_config {
      # Ephemeral IP to access from internet
    }
  }

  # Allow Cloud Build to SSH into this instance
  service_account {
    email  = google_service_account.cloud_build_sa.email
    scopes = ["cloud-platform"]
  }
}

# 4. Service Account for Cloud Build (to SSH and manage instances)
resource "google_service_account" "cloud_build_sa" {
  account_id   = "cloud-build-sa"
  display_name = "Service Account for Cloud Build"
}

# Grant Cloud Build service account necessary permissions
resource "google_project_iam_member" "cloudbuild_sa_compute_admin" {
  project = var.project_id
  role    = "roles/compute.instanceAdmin"
  member  = "serviceAccount:${google_service_account.cloud_build_sa.email}"
}

resource "google_project_iam_member" "cloudbuild_sa_service_account_user" {
  project = var.project_id
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${google_service_account.cloud_build_sa.email}"
}

# Grant Cloud Build default service account access to use this custom SA
resource "google_service_account_iam_member" "cloudbuild_use_sa" {
  service_account_id = google_service_account.cloud_build_sa.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${data.google_project.project.number}@cloudbuild.gserviceaccount.com"
}

# Get project number for Cloud Build default service account
data "google_project" "project" {
  project_id = var.project_id
}

# Grant Cloud Build default service account Compute Instance Admin
resource "google_project_iam_member" "cloudbuild_default_compute_admin" {
  project = var.project_id
  role    = "roles/compute.instanceAdmin.v1"
  member  = "serviceAccount:${data.google_project.project.number}@cloudbuild.gserviceaccount.com"
}

# Grant Cloud Build default service account Service Account User role
resource "google_project_iam_member" "cloudbuild_default_sa_user" {
  project = var.project_id
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${data.google_project.project.number}@cloudbuild.gserviceaccount.com"
}

# Output the VM IP and Repo name
output "vm_external_ip" {
  value = google_compute_instance.vm_instance.network_interface.0.access_config.0.nat_ip
}

output "artifact_registry_url" {
  value = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.my_repo.repository_id}"
}