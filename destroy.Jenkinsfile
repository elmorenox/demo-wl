pipeline {
    agent any
    
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
        
        stage('Terraform Destroy Plan') {
            steps {
                dir('app-infra') {
                    withCredentials([usernamePassword(credentialsId: 'aws-credentials', usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
                        sh '''
                        export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
                        export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY
                        terraform plan -destroy -out=destroy-plan
                        '''
                    }
                }
            }
        }
        
        stage('Terraform Destroy') {
            steps {
                dir('app-infra') {
                    withCredentials([usernamePassword(credentialsId: 'aws-credentials', usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
                        sh '''
                        export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
                        export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY
                        terraform apply destroy-plan
                        '''
                    }
                }
            }
        }
        
        stage('Cleanup') {
            steps {
                dir('app-infra') {
                    sh '''
                    rm -f destroy-plan
                    rm -f terraform.tfstate.backup
                    '''
                }
            }
        }
    }
    
    post {
        always {
            dir('app-infra') {
                // Archive terraform files for debugging
                archiveArtifacts artifacts: '*.tf, destroy-plan', allowEmptyArchive: true
            }
        }
        failure {
            echo 'Destroy pipeline failed! Check the logs for details.'
        }
        success {
            echo 'App infrastructure destroyed successfully!'
        }
    }
}