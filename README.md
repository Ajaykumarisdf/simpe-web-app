# Production-Like AWS Cloud Architecture Assessment

This repository contains a complete, production-grade cloud architecture for a simple containerized web application deployed on AWS.

## Architecture Highlights

1. **High Availability (HA)**: 
   - Deployed across 2 Availability Zones (`us-east-1a` and `us-east-1b`).
   - Auto Scaling Group spanning multiple private subnets.
   - Application Load Balancer (ALB) automatically distributing traffic to healthy instances.
   - **2 NAT Gateways**: We explicitly use two NAT Gateways (one per public subnet/AZ). This is a critical design decision for true HA. If AZ-1 fails, instances in AZ-2 can still reach the internet.

2. **Security & Least Privilege**:
   - **Private Subnets**: Application instances are in private subnets with no public IPs, completely shielded from direct internet access.
   - **No SSH Ports Open**: We use AWS Systems Manager (SSM) Session Manager for shell access. Port 22 is closed.
   - **IAM Roles**: EC2 instances authenticate to ECR and CloudWatch via IAM roles—no hardcoded passwords or access keys.

3. **Containerized CI/CD**:
   - Web application is Dockerized (Nginx based).
   - CI/CD uses **AWS Elastic Container Registry (ECR)** to store images.
   - Jenkins pipeline builds, tests locally, pushes to ECR, and triggers an ASG Instance Refresh for zero-downtime rolling updates.

4. **Monitoring**:
   - CloudWatch Agent is installed on instances via the bootstrap script.
   - Custom CloudWatch Dashboard tracks CPU, Memory, Disk, and Network usage.
   - CloudWatch Alarms trigger if CPU exceeds 80% or healthy instances drop below 2.

## Project Structure

- `terraform/`: Infrastructure as Code (VPC, Subnets, ALB, ASG, IAM, ECR, CloudWatch)
- `docker/`: Source code for the web app and Dockerfile
- `jenkins/`: Jenkinsfile CI/CD pipeline definition
- `scripts/`: EC2 user-data script for bootstrapping instances
- `monitoring/`: CloudWatch agent configuration JSON

## Deployment Instructions

### Prerequisites
- AWS CLI installed and configured locally (`aws configure`).
- Terraform installed (`>= 1.0.0`).
- Docker installed locally (for testing the build).

### Step 1: Deploy Infrastructure
```bash
cd terraform
terraform init
terraform plan
terraform apply --auto-approve
```
*Note: This will output the `alb_dns_name` and `ecr_repository_url`.*

### Step 2: CI/CD Pipeline Setup (Jenkins)
We use a local Jenkins installation to simulate the CI/CD pipeline, pushing to AWS ECR.

1. Ensure Jenkins is installed locally on your machine.
2. In Jenkins, create a new "Pipeline" project.
3. In the Pipeline section, choose "Pipeline script from SCM", point it to this local directory (or your Git repo), and specify `jenkins/Jenkinsfile` as the script path.
4. Run the build. 
   - The pipeline will authenticate with ECR using your local AWS credentials.
   - It will build the image, push it, and trigger an **ASG Instance Refresh**.

### Step 3: Verification
- Visit the ALB DNS name (from Terraform outputs) in your browser. You will see the "Demo HA Website".
- Refresh the page to see the `Instance ID` and `Availability Zone` change, proving traffic is load-balanced across multiple instances in different AZs.
- Go to the AWS Console -> CloudWatch -> Dashboards to view the automatically provisioned metrics.

## Design Decisions & Trade-Offs

- **AWS ECR vs Docker Hub**: We chose ECR. It integrates natively with IAM, meaning the EC2 instances don't need stored passwords to pull images.
- **Instance Refresh vs In-Place Updates**: We use ASG Instance Refresh for deployments. This follows the **Immutable Infrastructure** paradigm. We don't update existing instances; we replace them. This guarantees zero downtime and a clean state.
- **2 NAT Gateways vs 1 NAT Gateway**: We chose 2 NAT Gateways (one per AZ) to guarantee true HA. A single NAT gateway would save ~$32/month, but if its AZ goes down, the surviving AZ loses internet egress. 
- **Cost Awareness**: The architecture costs ~$95-$115/month (primarily due to the ALB and 2 NAT Gateways). Spot Instances were considered for the ASG to lower compute costs, but On-Demand `t3.micro` instances were chosen to guarantee availability for the assessment.

## Cleanup
To avoid ongoing AWS charges, destroy the infrastructure when done:
```bash
cd terraform
terraform destroy --auto-approve
```
