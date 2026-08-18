pipeline {

    agent any

    environment {
        AWS_REGION = 'us-east-2'
        AWS_ACCOUNT_ID = '982344023689'

        ECR_REPOSITORY = 'test-ecr'
        ECR_REGISTRY = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

        EKS_CLUSTER_NAME = 'my-test-eks'
        K8S_NAMESPACE = 'default'

        IMAGE = "${ECR_REGISTRY}/${ECR_REPOSITORY}:${BUILD_NUMBER}"
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
                        -t ${IMAGE} .

                    echo "Docker image built successfully."
                '''
            }
        }

        stage('Login to ECR') {
            steps {
                sh '''
                    echo "Logging into ECR..."

                    aws ecr get-login-password \
                        --region ${AWS_REGION} | \
                    docker login \
                        --username AWS \
                        --password-stdin ${ECR_REGISTRY}
                '''
            }
        }

        stage('Push Image to ECR') {
            steps {
                sh '''
                    echo "Pushing ${IMAGE}..."

                    docker push ${IMAGE}

                    echo "Image pushed successfully!"
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
                        -f kubernetes/ \
                        -n ${K8S_NAMESPACE}

                    echo "Updating deployment image..."

                    kubectl set image \
                        deployment/jenkins-eks-demo \
                        jenkins-eks-demo=${IMAGE} \
                        -n ${K8S_NAMESPACE}

                    echo "Waiting for rollout..."

                    kubectl rollout status \
                        deployment/jenkins-eks-demo \
                        -n ${K8S_NAMESPACE}
                '''
            }
        }

        stage('Verify') {
            steps {
                sh '''
                    echo "Deployment status:"

                    kubectl get deployment jenkins-eks-demo \
                        -n ${K8S_NAMESPACE}

                    echo "Pods:"

                    kubectl get pods \
                        -l app=jenkins-eks-demo \
                        -n ${K8S_NAMESPACE}
                '''
            }
        }
    }

    post {

        success {
            echo """
            ========================================
            DEPLOYMENT SUCCESSFUL
            ========================================
            Build: ${BUILD_NUMBER}
            Image: ${IMAGE}
            EKS Cluster: ${EKS_CLUSTER_NAME}
            ========================================
            """
        }

        failure {
            echo """
            ========================================
            PIPELINE FAILED
            ========================================
            Check the failed stage above.
            ========================================
            """
        }
    }
}