pipeline {

    agent any

    environment {
        AWS_REGION = 'us-east-2'
        AWS_ACCOUNT_ID = 'YOUR_AWS_ACCOUNT_ID'
        ECR_REPOSITORY = 'jenkins-eks-demo'
        EKS_CLUSTER_NAME = 'YOUR_EKS_CLUSTER_NAME'
        K8S_NAMESPACE = 'default'

        ECR_REGISTRY = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
        IMAGE_NAME = "${ECR_REGISTRY}/${ECR_REPOSITORY}"
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Test') {
            steps {
                sh '''
                    echo "Running application test..."

                    python3 -m py_compile app.py

                    echo "Test passed!"
                '''
            }
        }

        stage('Build Docker Image') {
            steps {
                sh '''
                    echo "Building Docker image..."

                    docker build \
                        -t ${ECR_REPOSITORY}:${BUILD_NUMBER} .

                    echo "Docker image built successfully."
                '''
            }
        }

        stage('Login to ECR') {
            steps {
                sh '''
                    echo "Logging into ECR..."

                    aws ecr get-login-password \
                        --region ${AWS_REGION} |
                    docker login \
                        --username AWS \
                        --password-stdin ${ECR_REGISTRY}
                '''
            }
        }

        stage('Push Image to ECR') {
            steps {
                sh '''
                    echo "Tagging Docker image..."

                    docker tag \
                        ${ECR_REPOSITORY}:${BUILD_NUMBER} \
                        ${IMAGE_NAME}:${BUILD_NUMBER}

                    echo "Pushing image to ECR..."

                    docker push \
                        ${IMAGE_NAME}:${BUILD_NUMBER}

                    echo "Image pushed successfully."
                '''
            }
        }

        stage('Deploy to EKS') {
            steps {
                sh '''
                    echo "Configuring kubectl..."

                    aws eks update-kubeconfig \
                        --region ${AWS_REGION} \
                        --name ${EKS_CLUSTER_NAME}

                    echo "Applying Kubernetes manifests..."

                    kubectl apply \
                        -f k8s/deployment.yaml \
                        -n ${K8S_NAMESPACE}

                    kubectl apply \
                        -f k8s/service.yaml \
                        -n ${K8S_NAMESPACE}

                    echo "Updating deployment image..."

                    kubectl set image deployment/jenkins-eks-demo \
                        jenkins-eks-demo=${IMAGE_NAME}:${BUILD_NUMBER} \
                        -n ${K8S_NAMESPACE}

                    echo "Waiting for rollout..."

                    kubectl rollout status \
                        deployment/jenkins-eks-demo \
                        -n ${K8S_NAMESPACE}
                '''
            }
        }
    }

    post {

        success {
            echo '========================================='
            echo 'Deployment successful!'
            echo "Docker Image: ${IMAGE_NAME}:${BUILD_NUMBER}"
            echo '========================================='
        }

        failure {
            echo '========================================='
            echo 'Pipeline failed!'
            echo 'Check the stage above for the error.'
            echo '========================================='
        }

        always {
            sh '''
                echo "Cleaning unused Docker images..."

                docker image prune -f || true
            '''
        }
    }
}