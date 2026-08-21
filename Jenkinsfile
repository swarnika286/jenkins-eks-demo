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
                        --target production \
                        -t ${IMAGE} .

                    echo "Docker image built successfully."
                '''
            }
        }

        stage('Scan Image') {
            steps {
                sh '''
                    echo "Scanning image for vulnerabilities..."

                    trivy image --severity CRITICAL,HIGH ${IMAGE}

                    echo "Security scan passed!"
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

        stage('Approve Deploy') {
            steps {
                input message: "Deploy ${env.IMAGE} to EKS cluster ${env.EKS_CLUSTER_NAME}?",
                      ok: 'Deploy'
            }
        }

        stage('Deploy to EKS') {
    steps {
        script {
            env.DEPLOYMENT_ATTEMPTED = 'true'

            sh '''
                echo "Configuring kubectl..."

                aws eks update-kubeconfig \
                    --region ${AWS_REGION} \
                    --name ${EKS_CLUSTER_NAME}

                echo "Deploying intentionally BAD image..."

                kubectl set image \
                    deployment/jenkins-eks-demo \
                    jenkins-eks-demo=${ECR_REGISTRY}/${ECR_REPOSITORY}:DOES-NOT-EXIST \
                    -n ${K8S_NAMESPACE}

                echo "Waiting for rollout..."

                kubectl rollout status \
                    deployment/jenkins-eks-demo \
                    -n ${K8S_NAMESPACE} \
                    --timeout=60s
            '''
        }
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

            script {

                if (env.DEPLOYMENT_ATTEMPTED == 'true') {

                    echo "Deployment was attempted."
                    echo "Attempting Kubernetes rollback..."

                    sh '''
                        aws eks update-kubeconfig \
                            --region ${AWS_REGION} \
                            --name ${EKS_CLUSTER_NAME}

                        kubectl rollout undo \
                            deployment/jenkins-eks-demo \
                            -n ${K8S_NAMESPACE}

                        kubectl rollout status \
                            deployment/jenkins-eks-demo \
                            -n ${K8S_NAMESPACE} \
                            --timeout=120s
                    '''

                    echo "Rollback completed."

                } else {

                    echo "Deployment was not attempted."
                    echo "Rollback is not required."

                }
            }
        }

        always {
            echo "Pipeline cleanup completed."
        }
    }
}