 Argo Workflows:
  - quay.io/argoproj/argocli:v3.7.2
  - quay.io/argoproj/workflow-controller:v3.7.2
  - quay.io/argoproj/argoexec:v3.7.2

  Argo Events:
  - quay.io/argoproj/argo-events:v1.9.2
  - nats-streaming:0.22.1

  Cert Manager:
  - quay.io/jetstack/cert-manager-cainjector:v1.14.1
  - quay.io/jetstack/cert-manager-controller:v1.14.1
  - quay.io/jetstack/cert-manager-webhook:v1.14.1

  Azure Service Operator:
  - mcr.microsoft.com/k8s/azureserviceoperator:v2.15.0

  Applications:
  - nginx:latest
  - nginx:1.21

  System Components:
  - registry.k8s.io/coredns/coredns:v1.12.0
  - registry.k8s.io/etcd:3.5.21-0
  - registry.k8s.io/kube-apiserver:v1.33.1
  - registry.k8s.io/kube-controller-manager:v1.33.1
  - registry.k8s.io/kube-proxy:v1.33.1
  - registry.k8s.io/kube-scheduler:v1.33.1

  Other:
  - ghcr.io/kro-run/kro/controller:0.4.1
  - docker.io/kindest/kindnetd:v20250512-df8de77b
  - docker.io/kindest/local-path-provisioner:v20250214-acbabc1a
  - natsio/prometheus-nats-exporter:0.8.0