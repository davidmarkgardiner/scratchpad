To clear out all pods before deleting a node in Azure Kubernetes Service (AKS) when using Node Auto Provisioner (which is based on Karpenter), you'll want to use a process called "cordoning and draining" the node. This safely evicts pods before removal.

Here's how you can do it:

1. First, cordon the node to prevent new pods from being scheduled on it:
   ```bash
   kubectl cordon <node-name>
   ```

2. Then drain the node to evict all existing pods:
   ```bash
   kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data
   ```
   - The `--ignore-daemonsets` flag skips daemon sets as they'll be recreated on other nodes
   - The `--delete-emptydir-data` flag allows deletion of pods with emptyDir volumes

3. Once the node is drained, you can safely delete it:
   ```bash
   kubectl delete node <node-name>
   ```

4. If using Karpenter directly, you can also use Karpenter's deletion API:
   ```bash
   kubectl annotate node <node-name> karpenter.sh/do-not-evict="false" karpenter.sh/do-not-disrupt="false" 
   kubectl annotate node <node-name> karpenter.sh/disruption="{\"deletionTimestamp\": \"$(date -u +'%Y-%m-%dT%H:%M:%SZ')\"}"
   ```

If you need to perform this operation on multiple nodes or automate it, you could create a script that handles the cordon, drain, and delete operations sequentially.

Note that when you drain a node, the pods will be rescheduled to other available nodes, so ensure you have sufficient capacity elsewhere in your cluster.