#!/bin/bash
set -e

# Delete any old configurations to start perfectly fresh
rm -f /etc/apt/sources.list.d/jenkins.list
rm -f /usr/share/keyrings/jenkins-keyring.gpg

echo "============================================="
echo " Installing Java (Required for Jenkins)"
echo "============================================="
apt update
apt install -y fontconfig openjdk-21-jre

echo "============================================="
echo " Installing Jenkins"
echo "============================================="
# Fetch the exact key (7198F4B714ABFC68) that apt is requesting from the Ubuntu keyserver
curl -fsSL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x7198F4B714ABFC68" | gpg --dearmor -o /usr/share/keyrings/jenkins-keyring.gpg --yes

echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.gpg] https://pkg.jenkins.io/debian-stable binary/" | tee /etc/apt/sources.list.d/jenkins.list > /dev/null

apt-get update
apt-get install -y jenkins

echo "============================================="
echo " Configuring Jenkins Permissions"
echo "============================================="
# Add Jenkins to the docker group so it can build images
usermod -aG docker jenkins

# Copy AWS credentials so Jenkins can push to ECR
mkdir -p /var/lib/jenkins/.aws
cp -r /home/ajay/.aws/* /var/lib/jenkins/.aws/ || echo "No AWS credentials found to copy."
chown -R jenkins:jenkins /var/lib/jenkins/.aws

# Restart Jenkins to apply group changes
systemctl enable jenkins
systemctl restart jenkins

echo "============================================="
echo " Installation Complete!"
echo "============================================="
echo "Jenkins is now running on http://localhost:8080"
echo ""
echo "To unlock Jenkins, open your browser and paste this password:"
cat /var/lib/jenkins/secrets/initialAdminPassword
echo "============================================="
