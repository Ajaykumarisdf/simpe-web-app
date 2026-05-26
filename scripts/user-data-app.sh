#!/bin/bash
set -ex

# Output all logs to a specific file
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "Starting user-data script execution"

# Update OS and install prerequisites
apt-get update -y
apt-get install -y apt-transport-https ca-certificates curl software-properties-common jq unzip

# Install AWS CLI v2
curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
./aws/install
rm -rf aws awscliv2.zip

# Install Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io
systemctl enable docker
systemctl start docker
usermod -aG docker ubuntu

# Install and configure CloudWatch Agent
curl -O https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
dpkg -i -E ./amazon-cloudwatch-agent.deb
rm -f ./amazon-cloudwatch-agent.deb

# Write the CloudWatch Agent configuration
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<'CWCONFIG'
{
    "agent": {
        "metrics_collection_interval": 60,
        "run_as_user": "root"
    },
    "metrics": {
        "append_dimensions": {
            "AutoScalingGroupName": "$${aws:AutoScalingGroupName}",
            "InstanceId": "$${aws:InstanceId}"
        },
        "metrics_collected": {
            "cpu": {
                "measurement": ["cpu_usage_idle", "cpu_usage_user", "cpu_usage_system"],
                "metrics_collection_interval": 60,
                "totalcpu": true
            },
            "disk": {
                "measurement": ["used_percent"],
                "metrics_collection_interval": 60,
                "resources": ["/"]
            },
            "mem": {
                "measurement": ["mem_used_percent"],
                "metrics_collection_interval": 60
            }
        }
    },
    "logs": {
        "logs_collected": {
            "files": {
                "collect_list": [
                    {
                        "file_path": "/var/log/user-data.log",
                        "log_group_name": "/ha-webapp/user-data",
                        "log_stream_name": "{instance_id}"
                    }
                ]
            }
        }
    }
}
CWCONFIG

# Start CloudWatch Agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config -m ec2 \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s

echo "CloudWatch Agent started successfully"

# ECR and Docker image setup
REGION="${aws_region}"
ECR_REPO_URL="${ecr_repo_url}"

# Login to ECR
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_REPO_URL

# Try to pull the image from ECR; if it fails (e.g., first deploy before Jenkins push), use fallback
IMAGE_URI="$ECR_REPO_URL:latest"

if docker pull $IMAGE_URI 2>/dev/null; then
    echo "Successfully pulled image from ECR: $IMAGE_URI"
else
    echo "Image not found in ECR (first deployment). Falling back to public nginx:alpine image."
    IMAGE_URI="nginx:alpine"
    docker pull $IMAGE_URI
fi

# Fetch Instance Metadata (IMDSv2)
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)
AZ=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/availability-zone)

# Run the Docker container
docker run -d \
  --name webapp \
  -p 80:80 \
  -e EC2_INSTANCE_ID=$INSTANCE_ID \
  -e EC2_AZ=$AZ \
  --restart unless-stopped \
  $IMAGE_URI

echo "User-data script completed successfully"
