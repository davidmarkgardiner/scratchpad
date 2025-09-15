 # image-updates.yaml
  # Argo Workflows image configurations
  argo-workflows:
    images:
      tag: "v3.7.2"  # Current version
      pullPolicy: Always

    controller:
      image:
        registry: quay.io
        repository: argoproj/workflow-controller
        tag: "v3.7.2"  # Override if needed

    executor:
      image:
        registry: quay.io
        repository: argoproj/argoexec
        tag: "v3.7.2"  # Override if needed

    server:
      image:
        registry: quay.io
        repository: argoproj/argocli
        tag: "v3.7.2"  # Override if needed

  # Argo Events image configurations
  argo-events:
    global:
      image:
        repository: quay.io/argoproj/argo-events
        tag: "v1.9.2"  # Current version
        imagePullPolicy: IfNotPresent

    controller:
      image:
        repository: ""  # Uses global.image.repository
        tag: ""         # Uses global.image.tag
        imagePullPolicy: ""  # Uses global.image.imagePullPolicy

    webhook:
      image:
        repository: ""  # Uses global.image.repository
        tag: ""         # Uses global.image.tag
        imagePullPolicy: ""  # Uses global.image.imagePullPolicy

    configs:
      nats:
        versions:
          - version: 0.22.1
            natsStreamingImage: nats-streaming:0.22.1
            metricsExporterImage: natsio/prometheus-nats-exporter:0.8.0
      jetstream:
        versions:
          - version: latest
            natsImage: nats:2.10.10
            metricsExporterImage: natsio/prometheus-nats-exporter:0.14.0
            configReloaderImage: natsio/nats-server-config-reloader:0.14.0

  Here are the commands to install the Helm charts:

  # Add Argo Helm repository
  helm repo add argo https://argoproj.github.io/argo-helm
  helm repo update

  # Install Argo Workflows
  helm install argo-workflows argo/argo-workflows \
    --namespace argo \
    --create-namespace \
    --values /Users/davidgardiner/Desktop/repo/argo-workflow/k8s/helm/argo-workflows/values.yaml

  # Install Argo Events  
  helm install argo-events argo/argo-events \
    --namespace argo-events \
    --create-namespace \
    --values /Users/davidgardiner/Desktop/repo/argo-workflow/k8s/helm/argo-events/values.yaml

  # To upgrade with new image versions:
  helm upgrade argo-workflows argo/argo-workflows \
    --namespace argo \
    --values /Users/davidgardiner/Desktop/repo/argo-workflow/k8s/helm/argo-workflows/values.yaml \
    --set images.tag=v3.8.0

  helm upgrade argo-events argo/argo-events \
    --namespace argo-events \
    --values /Users/davidgardiner/Desktop/repo/argo-workflow/k8s/helm/argo-events/values.yaml \
    --set global.image.tag=v1.10.0

  Key image update points:

  Argo Workflows:
  - images.tag: Global tag for all images
  - controller.image.tag: Specific controller image tag
  - executor.image.tag: Specific executor image tag
  - server.image.tag: Specific server image tag

  Argo Events:
  - global.image.tag: Global tag for controller and webhook
  - configs.nats.versions[].natsStreamingImage: NATS streaming image
  - configs.nats.versions[].metricsExporterImage: NATS metrics exporter
  - configs.jetstream.versions[].natsImage: JetStream NATS image
