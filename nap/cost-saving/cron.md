I understand your situation. Managing a shared cluster with 100+ app teams introduces unique cost-optimization challenges, especially when you want to enforce shutdowns during non-business hours like weekends. Let me explain how you can implement this with NAP.

## Implementing Scheduled Scale-Downs with NAP

NAP doesn't have a native "schedule-based" scaling mechanism like traditional AKS node pools. However, you can implement scheduled shutdowns using a combination of Kubernetes features and NAP's behavior:

### Solution: Scheduled Deployment Scaling + NAP Consolidation

1. **Scale App Deployments to Zero on Schedule**:
   - Use Kubernetes CronJobs to scale deployments to 0 replicas on Friday evenings
   - Use another CronJob to scale them back up on Monday mornings
   - When deployments scale to 0, their pods are removed
   - NAP then removes the empty nodes based on your consolidation policy

2. **Configure NAP for Efficient Node Removal**:
   - Set up NodePools with `WhenEmpty` consolidation policy
   - Set a short `consolidateAfter` period to remove nodes quickly after they become empty

### Implementation Steps:

#### 1. Create a CronJob to Scale Down Deployments (Friday Evening)

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: weekend-scale-down
spec:
  schedule: "0 18 * * 5"  # 6:00 PM every Friday
  jobTemplate:
    spec:
      template:
        spec:
          serviceAccountName: scale-manager  # Create with appropriate RBAC
          containers:
          - name: kubectl
            image: bitnami/kubectl:latest
            command:
            - /bin/sh
            - -c
            - |
              # Scale down deployments with specific label
              kubectl get deployments --all-namespaces -l weekend-scale=enabled -o json | jq -r '.items[] | .metadata.namespace + " " + .metadata.name' | while read ns name; do
                kubectl scale deployment -n $ns $name --replicas=0
              done
          restartPolicy: OnFailure
```

#### 2. Create a CronJob to Scale Up Deployments (Monday Morning)

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: weekend-scale-up
spec:
  schedule: "0 7 * * 1"  # 7:00 AM every Monday
  jobTemplate:
    spec:
      template:
        spec:
          serviceAccountName: scale-manager
          containers:
          - name: kubectl
            image: bitnami/kubectl:latest
            command:
            - /bin/sh
            - -c
            - |
              # Get deployments with our label and their original replica count from annotations
              kubectl get deployments --all-namespaces -l weekend-scale=enabled -o json | jq -r '.items[] | .metadata.namespace + " " + .metadata.name + " " + (.metadata.annotations["original-replicas"] // "1")' | while read ns name replicas; do
                kubectl scale deployment -n $ns $name --replicas=$replicas
              done
          restartPolicy: OnFailure
```

#### 3. Configure NAP NodePools for Fast Consolidation

```yaml
apiVersion: karpenter.sh/v1beta1
kind: NodePool
metadata:
  name: app-nodepool
spec:
  disruption:
    consolidationPolicy: WhenEmpty
    consolidateAfter: 5m  # Short period - remove nodes 5 minutes after they're empty
  template:
    spec:
      nodeClassRef:
        name: app-nodeclass
      requirements:
      - key: kubernetes.io/os
        operator: In
        values:
        - linux
      - key: karpenter.sh/capacity-type
        operator: In
        values:
        - on-demand
```

#### 4. Create RBAC for the Scale Manager Service Account

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: scale-manager
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: deployment-scaler
rules:
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "update", "patch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: scale-manager-binding
subjects:
- kind: ServiceAccount
  name: scale-manager
  namespace: kube-system
roleRef:
  kind: ClusterRole
  name: deployment-scaler
  apiGroup: rbac.authorization.k8s.io
```

### Implementation Notes:

1. **Application Team Adoption**: 
   - Teams simply need to add a label to their deployments: `weekend-scale: enabled`
   - Optionally, they can add an annotation with original replica count: `original-replicas: "3"`

2. **Preserve State/Configuration**: 
   - This approach only scales deployments, not StatefulSets or other resources
   - Application state stored in PVs remains untouched
   - All configuration remains intact

3. **Selective Application**:
   - Only deployments with the specific label are affected
   - Critical systems can be excluded by not applying the label

4. **Monitoring Considerations**:
   - Monitor the execution of these CronJobs to ensure they run correctly
   - Set up alerts for any failures in the scale-down/up process

This approach gives you centralized control over weekend shutdowns while letting application teams opt in by simply adding a label to their deployments. When the deployments scale down on Friday evening, NAP will automatically remove the empty nodes within 5 minutes, saving costs over the weekend.

Would you like me to expand on any aspect of this implementation or suggest alternative approaches?