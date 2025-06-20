I'll search for the latest information on AKS Istio add-on versions ASM-1-24 and ASM-1-25 to get you the most current details.Let me search for more specific information about ASM-1-25 and any recent announcements.Let me get the actual Istio release notes for version 1.24 and 1.25 to see what new features were introduced.Let me search for Istio 1.25 release notes specifically.Based on my research, here's what's new in AKS Istio add-on revisions ASM-1-24 and ASM-1-25:

## **ASM-1-24 (Available February 2025)**

ASM-1-24 is now available with Istio-based service mesh add-on and is compatible with AKS versions 1.28, 1.29, 1.30, 1.31, 1.32, and 1.33. The key new features based on upstream Istio 1.24 include:

### **Major Features:**
- **Ambient mode is generally available** - The core features (ztunnel, waypoints, and APIs) have been marked as Stable, making them fully ready for production usage
- **Improved retries** - Retries are now implemented on both client and server sidecars, with automatic detection and retry of server-side connection failures
- **Enhanced status messages** - New status messages are written to Services and AuthorizationPolicies to help understand object state
- **ServiceEntry policy attachment** - Policies can now be attached directly to ServiceEntry resources

### **Breaking Changes:**
This release removes the deprecated `istio.io/gateway-name` label - you should use `gateway.networking.k8s.io/gateway-name` label instead.

## **ASM-1-25 (Available April 2025)**

ASM-1-25 was updated to patch v1.25.2 and is based on upstream Istio 1.25. The major new features include:

### **Major Features:**
- **Enhanced policy targeting** - Ability to target policy to a named GatewayClass and named Gateway, allowing you to set policy on the istio-waypoint class that applies to all instances of a waypoint
- **Improved traffic distribution** - Kubernetes's traffic distribution feature is now fully supported, offering a simplified interface to keep traffic local
- **Enhanced metrics in ambient mode** - ztunnel now reports additional source_zone, source_region, destination_zone, and destination_region labels to all metrics
- **Virtual interface support** - Added ability to provide a list of virtual interfaces whose inbound traffic will be unconditionally treated as outbound

### **Compatibility:**
Istio 1.25.0 is officially supported on Kubernetes versions 1.29 to 1.32.

## **AKS-Specific Enhancements:**

Both revisions include AKS-specific improvements:
- **Enhanced upgrade capabilities** - You can now upgrade AKS clusters with the Istio add-on enabled regardless of compatibility with the current mesh revision
- **Customizable external traffic policy** - Users can now customize the externalTrafficPolicy field in the Istio ingress gateway Service spec
- **Security patches** - Recent updates include patches v1.24.5 and v1.25.2 with various security fixes

## **Upgrade Path:**

When upgrading from ASM-1-24 to ASM-1-25, you need to create a separate ConfigMap called istio-shared-configmap-asm-1-25 in the aks-istio-system namespace before initiating the canary upgrade.

These revisions represent significant improvements in ambient mode capabilities, traffic management, and operational visibility for AKS users.