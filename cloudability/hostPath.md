# Kubernetes Storage Options: Moving from hostPath to Container Storage

## Original hostPath Configuration
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: test-pod
spec:
  containers:
  - name: test-container
    image: nginx
    volumeMounts:
    - mountPath: /data
      name: test-volume
  volumes:
  - name: test-volume
    hostPath:
      path: /mnt/data
      type: Directory
```

## Alternative Storage Solutions

### 1. Ephemeral Storage with emptyDir
Best for temporary storage that can be lost when pod terminates.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: test-pod
spec:
  containers:
  - name: test-container
    image: nginx
    volumeMounts:
    - mountPath: /data
      name: test-volume
  volumes:
  - name: test-volume
    emptyDir: {}
```

### 2. Persistent Storage with PVC
Best for data that needs to survive pod restarts.

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
---
apiVersion: v1
kind: Pod
metadata:
  name: test-pod
spec:
  containers:
  - name: test-container
    image: nginx
    volumeMounts:
    - mountPath: /data
      name: test-volume
  volumes:
  - name: test-volume
    persistentVolumeClaim:
      claimName: test-pvc
```

### 3. Built-in Container Storage
Best for static application files.

```Dockerfile
FROM nginx
COPY ./my-data /data
```

## Choosing the Right Solution

Consider these factors when selecting a storage solution:

* Data persistence requirements
* Storage capacity needs
* Data sharing requirements between pods
* Application performance requirements
* Infrastructure constraints and available storage classes

### Key Differences

* emptyDir: Temporary storage, deleted with pod
* PersistentVolumeClaim: Permanent storage, survives pod restarts
* Built-in Container Storage: Static files, part of container image
