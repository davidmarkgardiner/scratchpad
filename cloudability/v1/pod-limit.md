No, with AKS CNI overlay you **don't** use /24 per node and you're **not** limited to 110 pods per node.

## **CNI Overlay vs Traditional Azure CNI**

**Traditional Azure CNI (what you're thinking of):**
- Each pod gets an IP from your VNet subnet
- /24 subnet = ~250 IPs available
- With IP reservation overhead: ~110 pods per node
- Limited by your VNet IP space

**CNI Overlay (what you should use):**
- Pods use overlay network (default: 10.244.0.0/16)
- **250 pods per node** by default
- Nodes still get VNet IPs, but pods don't consume VNet space
- No subnet size constraints for pod density

## **For 1000 Nodes with CNI Overlay:**

**Pod Capacity:**
- 1000 nodes × 250 pods = **250,000 pods maximum**

**IP Requirements:**
- **Node IPs**: 1000 (from your VNet subnet)
- **Pod IPs**: Handled by overlay network, doesn't consume VNet space
- You only need a subnet large enough for 1000+ node IPs

**Recommended Setup:**
- Node subnet: /22 (1024 IPs) or /21 (2048 IPs) for growth
- Pod CIDR: 10.244.0.0/16 (overlay, doesn't affect VNet)
- Service CIDR: 10.0.0.0/16 (cluster internal)

The key advantage of CNI overlay is that it **decouples pod networking from VNet IP consumption**, giving you much higher pod density without VNet subnet size constraints.

Are you planning to run close to 250 pods per node, or is this more about understanding the theoretical limits?