#!/bin/bash
# Jenkins setup script with Terraform installation and pipeline creation

# Update system packages
sudo apt update
sudo apt upgrade -y

# Install necessary packages
sudo apt install -y openjdk-17-jdk git python3 python3-pip python3-venv unzip wget curl

# Install Terraform
echo "Installing Terraform..."
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install -y terraform

# Add the Jenkins repository
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo tee \
  /usr/share/keyrings/jenkins-keyring.asc > /dev/null
echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
  https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null

# Update and install Jenkins
sudo apt update
sudo apt install -y jenkins

# Start Jenkins service
sudo systemctl enable jenkins
sudo systemctl start jenkins

# Wait for Jenkins to be fully up
echo "Waiting for Jenkins to be fully up..."
sleep 30

# Get the admin password
ADMIN_PASSWORD=$(sudo cat /var/lib/jenkins/secrets/initialAdminPassword)
echo "Jenkins initial admin password: $ADMIN_PASSWORD"

# Download Jenkins CLI
cd /tmp
wget -q -O jenkins-cli.jar http://localhost:8080/jnlpJars/jenkins-cli.jar
chmod +x jenkins-cli.jar

# Install necessary plugins
echo "Installing necessary plugins..."
java -jar jenkins-cli.jar -s http://localhost:8080/ -auth admin:$ADMIN_PASSWORD install-plugin workflow-aggregator git junit pipeline-stage-view blueocean pipeline-github-lib pipeline-rest-api credentials-binding -deploy

# Restart Jenkins
echo "Restarting Jenkins..."
java -jar jenkins-cli.jar -s http://localhost:8080/ -auth admin:$ADMIN_PASSWORD safe-restart

# Wait for Jenkins to restart
echo "Waiting for Jenkins to restart..."
sleep 60

# Create AWS credentials in Jenkins
echo "Creating AWS credentials in Jenkins..."
cat > /tmp/aws-credentials.xml << EOF
<?xml version="1.1" encoding="UTF-8"?>
<com.cloudbees.plugins.credentials.impl.UsernamePasswordCredentialsImpl>
  <scope>GLOBAL</scope>
  <id>aws-credentials</id>
  <description>AWS Credentials for Terraform</description>
  <username>${aws_access_key}</username>
  <password>${aws_secret_key}</password>
</com.cloudbees.plugins.credentials.impl.UsernamePasswordCredentialsImpl>
EOF

# Create the AWS credentials
echo "Creating AWS credentials..."
java -jar /tmp/jenkins-cli.jar -s http://localhost:8080 -auth admin:$ADMIN_PASSWORD create-credentials-by-xml \
  system::system::jenkins _ < /tmp/aws-credentials.xml || {
  echo "WARNING: Failed to create AWS credentials"
}

# Create Multibranch Pipeline job for app infrastructure
echo "Creating app infrastructure pipeline..."
cat > /tmp/app-infra-job.xml << 'EOL'
<?xml version='1.1' encoding='UTF-8'?>
<org.jenkinsci.plugins.workflow.multibranch.WorkflowMultiBranchProject plugin="workflow-multibranch">
  <actions/>
  <description>Pipeline for deploying application infrastructure</description>
  <properties>
    <org.jenkinsci.plugins.pipeline.modeldefinition.config.FolderConfig plugin="pipeline-model-definition">
      <dockerLabel></dockerLabel>
      <registry plugin="docker-commons"/>
    </org.jenkinsci.plugins.pipeline.modeldefinition.config.FolderConfig>
  </properties>
  <folderViews class="jenkins.branch.MultiBranchProjectViewHolder" plugin="branch-api">
    <owner class="org.jenkinsci.plugins.workflow.multibranch.WorkflowMultiBranchProject" reference="../.."/>
  </folderViews>
  <healthMetrics>
    <com.cloudbees.hudson.plugins.folder.health.WorstChildHealthMetric plugin="cloudbees-folder">
      <nonRecursive>false</nonRecursive>
    </com.cloudbees.hudson.plugins.folder.health.WorstChildHealthMetric>
  </healthMetrics>
  <icon class="jenkins.branch.MetadataActionFolderIcon" plugin="branch-api">
    <owner class="org.jenkinsci.plugins.workflow.multibranch.WorkflowMultiBranchProject" reference="../.."/>
  </icon>
  <orphanedItemStrategy class="com.cloudbees.hudson.plugins.folder.computed.DefaultOrphanedItemStrategy" plugin="cloudbees-folder">
    <pruneDeadBranches>true</pruneDeadBranches>
    <daysToKeep>-1</daysToKeep>
    <numToKeep>-1</numToKeep>
  </orphanedItemStrategy>
  <triggers/>
  <disabled>false</disabled>
  <sources class="jenkins.branch.MultiBranchProject$BranchSourceList" plugin="branch-api">
    <data>
      <jenkins.branch.BranchSource>
        <source class="jenkins.plugins.git.GitSCMSource" plugin="git">
          <id>app-infra-source</id>
          <remote>https://github.com/elmorenox/microblog_VPC_deployment.git</remote>
          <credentialsId></credentialsId>
          <traits>
            <jenkins.plugins.git.traits.BranchDiscoveryTrait/>
          </traits>
        </source>
        <strategy class="jenkins.branch.DefaultBranchPropertyStrategy">
          <properties class="empty-list"/>
        </strategy>
      </jenkins.branch.BranchSource>
    </data>
    <owner class="org.jenkinsci.plugins.workflow.multibranch.WorkflowMultiBranchProject" reference="../.."/>
  </sources>
  <factory class="org.jenkinsci.plugins.workflow.multibranch.WorkflowBranchProjectFactory">
    <owner class="org.jenkinsci.plugins.workflow.multibranch.WorkflowMultiBranchProject" reference="../.."/>
    <scriptPath>Jenkinsfile</scriptPath>
  </factory>
</org.jenkinsci.plugins.workflow.multibranch.WorkflowMultiBranchProject>
EOL

echo "Creating job 'app-infrastructure-deployment'..."
java -jar /tmp/jenkins-cli.jar -s http://localhost:8080/ -auth admin:$ADMIN_PASSWORD create-job app-infrastructure-deployment < /tmp/app-infra-job.xml

# Clean up temporary files
rm -f /tmp/aws-credentials.xml /tmp/app-infra-job.xml /tmp/jenkins-cli.jar

echo "Jenkins configuration complete!"
echo "Pipeline 'app-infrastructure-deployment' has been created (manual trigger only)."
echo "Initial admin password: $ADMIN_PASSWORD"
echo "Jenkins URL: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080"