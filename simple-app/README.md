# Simple App Helm Chart

A simple Helm chart that deploys a basic Nginx application to Kubernetes.

## Prerequisites

- Kubernetes 1.19+
- Helm 3.2.0+

## Installing the Chart

To install the chart with the release name `my-release`:

```console
$ helm install my-release ./simple-app
```

The command deploys a simple Nginx application on the Kubernetes cluster in the default configuration.

## Uninstalling the Chart

To uninstall/delete the `my-release` deployment:

```console
$ helm uninstall my-release
```

## Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicaCount` | Number of replicas | `1` |
| `image.repository` | Image repository | `nginx` |
| `image.tag` | Image tag | `stable` |
| `image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `service.type` | Kubernetes service type | `ClusterIP` |
| `service.port` | Service port | `80` |
| `resources.limits.cpu` | CPU limits | `100m` |
| `resources.limits.memory` | Memory limits | `128Mi` |
| `resources.requests.cpu` | CPU requests | `50m` |
| `resources.requests.memory` | Memory requests | `64Mi` |

## Example: Customizing values

Create a `values-custom.yaml` file:

```yaml
replicaCount: 3
image:
  repository: nginx
  tag: latest
service:
  type: NodePort
```

Then install the chart with custom values:

```console
$ helm install my-release ./simple-app -f values-custom.yaml
``` 