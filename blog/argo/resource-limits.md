 # image-updates-with-resources.yaml
  # Argo Workflows image configurations with resource limits
  argo-workflows:
    images:
      tag: "v3.7.2"  # Current version
      pullPolicy: Always

    controller:
      image:
        registry: quay.io
        repository: argoproj/workflow-controller
        tag: "v3.7.2"
      # Resource limits for workflow controller
      resources:
        limits:
          cpu: 500m
          memory: 512Mi
        requests:
          cpu: 100m
          memory: 128Mi

    executor:
      image:
        registry: quay.io
        repository: argoproj/argoexec
        tag: "v3.7.2"
      # Resource limits for workflow executors
      resources:
        limits:
          cpu: 200m
          memory: 256Mi
        requests:
          cpu: 50m
          memory: 64Mi

    server:
      image:
        registry: quay.io
        repository: argoproj/argocli
        tag: "v3.7.2"
      # Resource limits for Argo server
      resources:
        limits:
          cpu: 500m
          memory: 512Mi
        requests:
          cpu: 100m
          memory: 128Mi
      # Server autoscaling configuration
      autoscaling:
        enabled: true
        minReplicas: 1
        maxReplicas: 3
        targetCPUUtilizationPercentage: 70
        targetMemoryUtilizationPercentage: 80

    # Main container resource defaults for workflows
    mainContainer:
      resources:
        limits:
          cpu: 1000m
          memory: 1Gi
        requests:
          cpu: 100m
          memory: 128Mi

  # Argo Events image configurations with resource limits
  argo-events:
    global:
      image:
        repository: quay.io/argoproj/argo-events
        tag: "v1.9.2"
        imagePullPolicy: IfNotPresent

    controller:
      image:
        repository: ""  # Uses global.image.repository
        tag: ""         # Uses global.image.tag
        imagePullPolicy: ""
      # Resource limits for events controller
      resources:
        limits:
          cpu: 500m
          memory: 512Mi
        requests:
          cpu: 100m
          memory: 128Mi
      replicas: 1

    webhook:
      enabled: true
      image:
        repository: ""  # Uses global.image.repository
        tag: ""         # Uses global.image.tag
        imagePullPolicy: ""
      # Resource limits for admission webhook
      resources:
        limits:
          cpu: 200m
          memory: 256Mi
        requests:
          cpu: 50m
          memory: 64Mi
      replicas: 1