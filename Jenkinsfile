pipeline {
    agent any
    
    environment {
        TF_VAR_ssh_key_name = 'your-key-name'  // Update this with your actual key name
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        
        stage('Terraform Init') {
            steps {
                dir('app-infra') {
                    withCredentials([usernamePassword(credentialsId: 'aws-credentials', usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
                        sh '''
                        export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
                        export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY
                        terraform init
                        '''
                    }
                }
            }
        }
        
        stage('Terraform Plan') {
            steps {
                dir('app-infra') {
                    withCredentials([usernamePassword(credentialsId: 'aws-credentials', usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
                        sh '''
                        export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
                        export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY
                        terraform plan -out=tfplan
                        '''
                    }
                }
            }
        }
        
        stage('Terraform Apply') {
            steps {
                dir('app-infra') {
                    input message: 'Deploy infrastructure?', ok: 'Deploy'
                    withCredentials([usernamePassword(credentialsId: 'aws-credentials', usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
                        sh '''
                        export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
                        export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY
                        terraform apply tfplan
                        '''
                    }
                }
            }
        }
        
        stage('Output Results') {
            steps {
                dir('app-infra') {
                    withCredentials([usernamePassword(credentialsId: 'aws-credentials', usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
                        sh '''
                        export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
                        export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY
                        terraform output
                        '''
                    }
                }
            }
        }
    }
    
    post {
        always {
            dir('app-infra') {
                // Archive terraform files for debugging
                archiveArtifacts artifacts: '*.tf, *.tfplan', allowEmptyArchive: true
            }
        }
        failure {
            echo 'Pipeline failed! Check the logs for details.'
        }
        success {
            echo 'Infrastructure deployed successfully!'
        }
    }
}