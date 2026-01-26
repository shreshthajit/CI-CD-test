# CI/CD Pipeline Project

A complete CI/CD pipeline setup using Google Cloud Platform (GCP) with Terraform for infrastructure, Cloud Build for CI/CD, and Docker for containerization.

## Project Structure

```
.
├── app.py                 # Flask application
├── dockerfile            # Docker image configuration
├── requirements.txt      # Python dependencies
├── cloudbuild.yaml       # Google Cloud Build CI/CD configuration
├── infra/               # Terraform infrastructure code
│   ├── main.tf          # Main infrastructure definitions
│   └── variables.tf     # Terraform variables
└── README.md            # This file
```

## Architecture

1. **Application**: Flask-based Python web application
2. **Containerization**: Docker
3. **Infrastructure**: Terraform-managed GCP resources
4. **CI/CD**: Google Cloud Build
5. **Deployment**: Docker container on GCP Compute Engine VM

## Prerequisites

- Google Cloud Platform account with billing enabled
- `gcloud` CLI installed and configured
- `terraform` installed
- `docker` installed (for local testing)
- Python 3.9+ (for local development)

## Setup Instructions

### 1. Initialize GCP Project

```bash
# Set your project ID
export PROJECT_ID="your-project-id"
gcloud config set project $PROJECT_ID

# Enable required APIs
gcloud services enable compute.googleapis.com
gcloud services enable artifactregistry.googleapis.com
gcloud services enable cloudbuild.googleapis.com
gcloud services enable iam.googleapis.com
```

### 2. Configure Terraform Variables

Edit `infra/variables.tf` and update the `project_id`:

```hcl
variable "project_id" {
  description = "your-project-id"
}
```

### 3. Deploy Infrastructure

```bash
cd infra
terraform init
terraform plan
terraform apply
```

This will create:
- Artifact Registry repository for Docker images
- Compute Engine VM instance
- Firewall rules
- Service account for Cloud Build

### 4. Configure Cloud Build

After Terraform completes, note the outputs:
- `vm_external_ip`: Your VM's public IP
- `artifact_registry_url`: Your Docker registry URL

#### Create Cloud Build Trigger

1. Go to Cloud Build > Triggers in GCP Console
2. Create a new trigger
3. Connect your repository (GitHub, Cloud Source Repositories, etc.)
4. Set the configuration file to `cloudbuild.yaml`
5. Configure substitution variables:
   - `_REGION`: `us-central1` (or your region)
   - `_REPO_NAME`: `python-backend-repo`
   - `_VM_ZONE`: `us-central1-a` (or your zone)
   - `_VM_NAME`: `python-backend-vm`

### 5. Set Up VM Access

The VM needs to allow Cloud Build to SSH into it. You may need to:

```bash
# Get the VM name and zone from Terraform output
VM_NAME="python-backend-vm"
VM_ZONE="us-central1-a"

# Add Cloud Build service account to VM's metadata
gcloud compute instances add-metadata $VM_NAME \
  --zone=$VM_ZONE \
  --metadata=enable-oslogin=TRUE
```

### 6. Test Locally (Optional)

```bash
# Build Docker image locally
docker build -t python-app:local .

# Run container
docker run -p 8080:8080 python-app:local

# Test the API
curl http://localhost:8080
curl http://localhost:8080/health
```

## CI/CD Pipeline Flow

1. **Push to Repository**: When you push code to your repository
2. **Cloud Build Trigger**: Cloud Build automatically starts
3. **Build Docker Image**: Creates Docker image from your code
4. **Push to Artifact Registry**: Stores the image in GCP Artifact Registry
5. **Deploy to VM**: SSHs into the VM and:
   - Stops existing container
   - Pulls latest image
   - Runs new container

## Manual Deployment

If you want to deploy manually:

```bash
# Build and push image
gcloud builds submit --config=cloudbuild.yaml

# Or deploy directly
VM_NAME="python-backend-vm"
VM_ZONE="us-central1-a"
IMAGE_NAME="us-central1-docker.pkg.dev/$PROJECT_ID/python-backend-repo/python-app:latest"

gcloud compute ssh $VM_NAME --zone=$VM_ZONE --command="
  docker stop python-backend || true
  docker rm python-backend || true
  docker pull $IMAGE_NAME
  docker run -d -p 8080:8080 --name python-backend $IMAGE_NAME
"
```

## Accessing the Application

After deployment, access your application at:
```
http://<VM_EXTERNAL_IP>:8080
```

Endpoints:
- `GET /` - Welcome message
- `GET /health` - Health check
- `GET /api/info` - Application info

## Next Steps for Learning

1. **Add Testing**: Integrate unit tests in Cloud Build pipeline
2. **Add Staging Environment**: Create separate staging and production environments
3. **Add Monitoring**: Set up Cloud Monitoring and Logging
4. **Add Secrets Management**: Use Secret Manager for sensitive data
5. **Add Load Balancer**: Use GCP Load Balancer for high availability
6. **Add Auto-scaling**: Configure instance groups with auto-scaling
7. **Add GitHub Actions**: Alternative CI/CD with GitHub Actions
8. **Add Kubernetes**: Migrate to GKE for container orchestration

## Troubleshooting

### Cloud Build fails to SSH into VM
- Check IAM permissions for Cloud Build service account
- Verify VM has OS Login enabled
- Check firewall rules allow SSH

### Container fails to start
- Check VM logs: `gcloud compute instances get-serial-port-output $VM_NAME --zone=$VM_ZONE`
- Verify Docker is running on VM
- Check container logs: `docker logs python-backend`

### Image push fails
- Verify Artifact Registry repository exists
- Check Cloud Build service account has Artifact Registry Writer role

## Clean Up

To destroy all resources:

```bash
cd infra
terraform destroy
```

## Resources

- [Google Cloud Build Documentation](https://cloud.google.com/build/docs)
- [Terraform GCP Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [Artifact Registry Documentation](https://cloud.google.com/artifact-registry/docs)

