 1. Basic Test Workflow Submission

  # test-workflow-basic.yaml
  apiVersion: argoproj.io/v1alpha1
  kind: Workflow
  metadata:
    name: test-namespace-onboarding-basic
    namespace: argo
    labels:
      test: "basic"
  spec:
    workflowTemplateRef:
      name: namespace-onboarding-template
    arguments:
      parameters:
        - name: payload
          value: |
            {
              "NamespaceName": "test-app-dev",
              "Environment": "DEV",
              "Swc": "AA11111",
              "ResourceQuotaCPU": 2,
              "ResourceQuotaMemoryGB": 4,
              "ResourceQuotaStorageGB": 10,
              "AllowAccessFromNS": "default",
              "ManagedAksClusterName": "minikube"
            }
        - name: targetCluster
          value: "minikube"

  2. Production-like Test

  # test-workflow-production.yaml
  apiVersion: argoproj.io/v1alpha1
  kind: Workflow
  metadata:
    name: test-namespace-onboarding-prod
    namespace: argo
    labels:
      test: "production"
  spec:
    workflowTemplateRef:
      name: namespace-onboarding-template
    arguments:
      parameters:
        - name: payload
          value: |
            {
              "NamespaceName": "ecommerce-prod",
              "Environment": "PROD",
              "Swc": "EC12345",
              "ResourceQuotaCPU": 8,
              "ResourceQuotaMemoryGB": 16,
              "ResourceQuotaStorageGB": 100,
              "AllowAccessFromNS": "monitoring",
              "ManagedAksClusterName": "minikube"
            }
        - name: targetCluster
          value: "minikube"

  3. Minimal Test (Testing Defaults)

  # test-workflow-minimal.yaml
  apiVersion: argoproj.io/v1alpha1
  kind: Workflow
  metadata:
    name: test-namespace-onboarding-minimal
    namespace: argo
    labels:
      test: "minimal"
  spec:
    workflowTemplateRef:
      name: namespace-onboarding-template
    arguments:
      parameters:
        - name: payload
          value: |
            {
              "NamespaceName": "minimal-test"
            }
        - name: targetCluster
          value: "minikube"

  4. Multiple Environment Tests

  # test-workflow-batch.yaml
  apiVersion: argoproj.io/v1alpha1
  kind: Workflow
  metadata:
    name: test-namespace-onboarding-batch
    namespace: argo
    labels:
      test: "batch"
  spec:
    entrypoint: test-multiple-environments
    templates:
      - name: test-multiple-environments
        steps:
          - - name: test-dev
              templateRef:
                name: namespace-onboarding-template
                template: main
              arguments:
                parameters:
                  - name: payload
                    value: |
                      {
                        "NamespaceName": "myapp-dev",
                        "Environment": "DEV",
                        "Swc": "APP001",
                        "ResourceQuotaCPU": 2,
                        "ResourceQuotaMemoryGB": 4,
                        "ResourceQuotaStorageGB": 5
                      }
                  - name: targetCluster
                    value: "minikube"
          - - name: test-staging
              templateRef:
                name: namespace-onboarding-template
                template: main
              arguments:
                parameters:
                  - name: payload
                    value: |
                      {
                        "NamespaceName": "myapp-staging",
                        "Environment": "STAGING",
                        "Swc": "APP001",
                        "ResourceQuotaCPU": 4,
                        "ResourceQuotaMemoryGB": 8,
                        "ResourceQuotaStorageGB": 20,
                        "AllowAccessFromNS": "myapp-dev"
                      }
                  - name: targetCluster
                    value: "minikube"

  5. Error Testing (Invalid Input)

  # test-workflow-error.yaml
  apiVersion: argoproj.io/v1alpha1
  kind: Workflow
  metadata:
    name: test-namespace-onboarding-error
    namespace: argo
    labels:
      test: "error-handling"
  spec:
    workflowTemplateRef:
      name: namespace-onboarding-template
    arguments:
      parameters:
        - name: payload
          value: |
            {
              "NamespaceName": "INVALID-NAME-WITH-CAPS",
              "Environment": "INVALID_ENV",
              "Swc": "invalid-swc-lowercase",
              "ResourceQuotaCPU": "invalid",
              "ResourceQuotaMemoryGB": -1
            }
        - name: targetCluster
          value: "minikube"

  6. Test Commands

  # Apply the workflow template first
  kubectl apply -f /Users/davidgardiner/Desktop/repo/argo-workflow/k8s/argo-events/06-enhanced-workflow-template.yaml

  # Run basic test
  kubectl apply -f test-workflow-basic.yaml

  # Monitor the workflow
  argo watch test-namespace-onboarding-basic -n argo

  # Get workflow status
  argo get test-namespace-onboarding-basic -n argo

  # View workflow logs
  argo logs test-namespace-onboarding-basic -n argo

  # List all workflows
  argo list -n argo

  # Clean up test workflows
  argo delete test-namespace-onboarding-basic -n argo
  kubectl delete namespace test-app-dev --ignore-not-found=true

  7. Quick Test Script

  #!/bin/bash
  # test-workflow.sh

  echo "Testing namespace onboarding workflow..."

  # Test 1: Basic test
  echo "Running basic test..."
  kubectl apply -f test-workflow-basic.yaml
  argo wait test-namespace-onboarding-basic -n argo

  # Test 2: Check created namespace
  echo "Checking created namespace..."
  kubectl get namespace test-app-dev -o yaml

  # Test 3: Check resource quota
  echo "Checking resource quota..."
  kubectl get resourcequota -n test-app-dev

  # Test 4: Check network policies
  echo "Checking network policies..."
  kubectl get networkpolicy -n test-app-dev

  # Cleanup
  echo "Cleaning up..."
  argo delete test-namespace-onboarding-basic -n argo
  kubectl delete namespace test-app-dev

  Choose the test that matches your needs:
  - Basic test: Standard namespace creation
  - Production test: Higher resource limits
  - Minimal test: Tests default values
  - Batch test: Multiple environments
  - Error test: Validates error handling