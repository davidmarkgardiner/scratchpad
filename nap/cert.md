To inject certificates into NAP nodes, you'll need to configure this in the AKSNodeClass. Here are the steps:

1. First, check your current AKSNodeClass:
```bash
kubectl get aksnodeclass default -o yaml
```

2. Modify or create a new AKSNodeClass with certificate configuration:
```yaml
apiVersion: karpenter.azure.com/v1alpha2
kind: AKSNodeClass
metadata:
  name: default
spec:
  imageFamily: Ubuntu2204  # or AzureLinux
  osDiskSizeGB: 128
  customData: |
    #cloud-config
    write_files:
    - path: /etc/ssl/certs/custom-ca.crt
      permissions: '0644'
      content: |
        -----BEGIN CERTIFICATE-----
        Your certificate content here
        -----END CERTIFICATE-----
    runcmd:
    - update-ca-certificates
```

3. Your NodePool remains the same, referencing this AKSNodeClass:
```yaml
apiVersion: karpenter.sh/v1beta1
kind: NodePool
metadata:
  name: default
spec:
  template:
    spec:
      nodeClassRef:
        name: default
      requirements:
      - key: kubernetes.io/arch
        operator: In
        values:
        - amd64
```

Note: 
- The customData field uses cloud-init format
- The certificate will be installed during node bootstrapping
- All new nodes provisioned by NAP will get this certificate
- Existing nodes won't be automatically updated

Would you like me to show you how to verify the certificate installation or handle multiple certificates?
