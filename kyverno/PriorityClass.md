nameOverride: ""
fullnameOverride: ""

global:
  namespace: kyverno
  labels:
    instance: kyverno
    part-of: kyverno

replicaCount: 1

images:
  kyverno:
    repository: ghcr.io/kyverno/kyverno
    tag: v1.11.4
    pullPolicy: IfNotPresent
  backgroundController:
    repository: ghcr.io/kyverno/background-controller
    tag: v1.11.4
    pullPolicy: IfNotPresent
  cleanupController:
    repository: ghcr.io/kyverno/cleanup-controller
    tag: v1.11.4
    pullPolicy: IfNotPresent
  reportsController:
    repository: ghcr.io/kyverno/reports-controller
    tag: v1.11.4
    pullPolicy: IfNotPresent

resources:
  kyverno:
    limits:
      memory: 512Mi
    requests:
      cpu: 100m
      memory: 256Mi
  controllers:
    limits:
      memory: 256Mi
    requests:
      cpu: 100m
      memory: 128Mi

services:
  kyverno:
    type: ClusterIP
    port: 443
    targetPort: 9443
  metrics:
    type: ClusterIP
    port: 8000
    targetPort: 8000

components:
  admissionController:
    name: admission-controller
    priorityClassName: kyverno-critical
    service:
      purpose: service
    metricsService:
      purpose: metrics
  backgroundController:
    name: background-controller
    priorityClassName: kyverno-high
    metricsService:
      purpose: metrics
  cleanupController:
    name: cleanup-controller
    priorityClassName: kyverno-high
    metricsService:
      purpose: metrics
  reportsController:
    name: reports-controller
    priorityClassName: kyverno-high
    metricsService:
      purpose: metrics 


---

apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: kyverno-critical
value: 1000000
globalDefault: false
description: "This priority class should be used for Kyverno admission controller pods only."
---
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: kyverno-high
value: 900000
globalDefault: false
description: "This priority class should be used for Kyverno controller pods."
