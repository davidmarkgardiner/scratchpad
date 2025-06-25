Based on the Azure Kubernetes Service documentation you provided, I'll create a comprehensive YAML configuration for deploying GPU-enabled node pools using Node Autoprovisioning (NAP). This will include both the NodePool and AKSNodeClass configurations optimized for GPU workloads.I've created a comprehensive GPU Node Autoprovisioning configuration for AKS that includes:

## Key Components:

1. **AKSNodeClass** (`gpu-nodeclass`):
   - Ubuntu 22.04 image family (recommended for GPU workloads)
   - Larger OS disk (256GB) for GPU workload requirements
   - Optional image version pinning for consistency

2. **NodePool** (`gpu-nodepool`):
   - **Conservative disruption policy**: Only consolidates when nodes are empty to avoid interrupting GPU workloads
   - **Resource limits**: Prevents runaway costs while allowing sufficient capacity
   - **High priority weight**: Ensures GPU workloads get preference
   - **Comprehensive GPU requirements**: Targets NVIDIA GPUs with specific families and minimum specs

3. **GPU-Specific Features**:
   - Taints to ensure only GPU workloads are scheduled on these expensive nodes
   - Support for multiple GPU types (V100, T4, A100, K80)
   - Targets appropriate VM families (NC, NCv2, NCv3, ND, NDv2)
   - Minimum hardware specs suitable for GPU workloads

4. **Additional Resources**:
   - **Test workload**: TensorFlow GPU job to validate the setup
   - **NVIDIA Device Plugin**: DaemonSet to enable GPU scheduling

## Usage Instructions:

1. **Prerequisites**: Ensure your AKS cluster has Node Autoprovisioning enabled with the required networking configuration
2. **Apply the configuration**: `kubectl apply -f gpu-nodepool-config.yaml`
3. **Monitor**: Use `kubectl get events -A --field-selector source=karpenter -w` to watch node provisioning
4. **Test**: Deploy the included test workload to verify GPU functionality

## Customization Options:

- Adjust `availabilityZones` to match your Azure region
- Modify GPU types in the requirements based on your specific needs
- Change capacity type from `on-demand` to `spot` for cost savings (with reduced reliability)
- Adjust resource limits based on your budget and scaling requirements

This configuration provides a production-ready foundation for GPU workloads in AKS with intelligent autoscaling and cost controls.