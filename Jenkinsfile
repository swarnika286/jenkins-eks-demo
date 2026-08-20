pipeline {

    agent any

    environment {
        AWS_REGION = 'us-east-2'
        AWS_ACCOUNT_ID = '982344023689'

        ECR_REPOSITORY = 'test-ecr'
        ECR_REGISTRY = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

        EKS_CLUSTER_NAME = 'my-test-eks'
        K8S_NAMESPACE = 'default'
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
                    echo "Running application tests..."

                    docker build \
                        --target test \
                        -t jenkins-eks-demo-test .

                    echo "Running pytest inside Docker..."

                    docker run --rm \
                        jenkins-eks-demo-test \
                        pytest

                    echo "All tests passed!"
                '''
            }
        }

        stage('Set Image Tag') {
            steps {
                script {
                    env.GIT_COMMIT_SHORT = sh(
                        script: 'git rev-parse --short HEAD',
                        returnStdout: true
                    ).trim()

                    env.IMAGE = "${env.ECR_REGISTRY}/${env.ECR_REPOSITORY}:${env.BUILD_NUMBER}-${env.GIT_COMMIT_SHORT}"

                    echo "Git Commit: ${env.GIT_COMMIT_SHORT}"
                    echo "Docker Image: ${env.IMAGE}"
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                sh '''
                    echo "Building production Docker image..."

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
            Git Commit: ${GIT_COMMIT_SHORT}
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