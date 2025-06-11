# Two-Phase Terraform Deployment

## Phase 1: Jenkins Infrastructure
Deploy Jenkins server and basic networking:
```bash
cd jenkins-infra
terraform init
terraform plan
terraform apply
```

## Phase 2: Application Infrastructure
Use Jenkins pipeline to deploy remaining infrastructure:
1. Access Jenkins at the provided URL
2. Navigate to "app-infrastructure-deployment" pipeline
3. Trigger build manually
4. Approve deployment when prompted

## Directory Structure
- `jenkins-infra/` - Creates VPC, networking, and Jenkins server
- `app-infra/` - Contains Terraform for web, app, and monitoring servers
