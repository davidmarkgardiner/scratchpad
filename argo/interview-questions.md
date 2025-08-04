Here are 10 more quick technical questions:

## Additional Quick Knowledge Checks

1. **"What happens when you set a pod's resource request higher than any node's available capacity?"**
   *Looking for: Pod stays in Pending state, needs node scaling or request adjustment*

2. **"In a NetworkPolicy, what's the difference between 'ingress' and 'egress' rules?"**
   *Ingress controls incoming traffic to pods, egress controls outgoing traffic from pods*

3. **"If 'kubectl get nodes' shows a node as 'NotReady', name three things you'd check first."**
   *Should mention: kubelet status, network connectivity, disk/memory pressure*

4. **"What's a ServiceMonitor in the Prometheus ecosystem?"**
   *CRD that tells Prometheus which services to scrape for metrics*

5. **"When would you use a StatefulSet instead of a Deployment?"**
   *For applications needing stable network identity, persistent storage, or ordered deployment*

6. **"What's the purpose of a PodSecurityPolicy or Pod Security Standards?"**
   *Control what security contexts and capabilities pods can use*

7. **"If an application can't resolve DNS names inside the cluster, what DNS-related things would you check?"**
   *CoreDNS pods, kube-dns service, pod's DNS policy, search domains*

8. **"What's a DaemonSet and give me an example of when you'd use one?"**
   *Runs one pod per node, examples: log collectors, monitoring agents, CNI plugins*

9. **"In Istio, what does 'PERMISSIVE' mTLS mode mean?"**
   *Accepts both plain text and mTLS traffic, useful for gradual migration*

10. **"What's the difference between 'kubectl apply' and 'kubectl create'?"**
    *Apply is declarative/idempotent, create is imperative and fails if resource exists*

These continue testing practical Kubernetes and platform knowledge that's essential for day-to-day work on your team.


Here are 8 quick technical questions for immediate feedback:

## Quick Knowledge Checks

1. **"What's the difference between a ClusterRole and a Role in Kubernetes RBAC?"**
   *Should know: ClusterRole is cluster-wide, Role is namespace-scoped*

2. **"If a pod shows 'ImagePullBackOff' status, what are the three most common causes?"**
   *Looking for: Wrong image name/tag, registry authentication issues, network connectivity*

3. **"In Istio, what's the difference between a VirtualService and a DestinationRule?"**
   *Should know: VirtualService routes traffic, DestinationRule defines policies for destinations*

4. **"What does it mean when kubectl shows a pod in 'CrashLoopBackOff' state?"**
   *Looking for: Container starts, crashes, Kubernetes keeps restarting with backoff delay*

5. **"Name three ways External-DNS can discover services to create DNS records for."**
   *Should mention: Ingress annotations, Service annotations, CRDs like HTTPRoute*

6. **"What's a NodeSelector vs NodeAffinity in Kubernetes scheduling?"**
   *NodeSelector is simple key-value matching, NodeAffinity is more flexible with operators*

7. **"If you see 'certificate verify failed' errors in your application logs, what Istio configuration might be the issue?"**
   *Looking for: mTLS settings, DestinationRule TLS mode, PeerAuthentication policies*

8. **"What's the difference between a Kubernetes Secret and using External Secrets Operator?"**
   *ESO fetches secrets from external systems vs storing directly in etcd*

---

Based on your platform description, here are 5 medium to hard technical questions that will help assess the candidate's knowledge across the key areas they'll be working with:

## 1. Kubernetes RBAC and Multi-tenancy Architecture
**Question:** "You mentioned we have an automated onboarding process that creates namespaces with RBAC bindings. Walk me through how you would design a secure multi-tenant RBAC strategy for a Kubernetes cluster where teams should only access their own namespaces. What are the potential security pitfalls, and how would you prevent privilege escalation? Also, explain how NetworkPolicies fit into this isolation model."

*This tests their understanding of Kubernetes security, RBAC design patterns, and namespace isolation - critical for your automated onboarding process.*

## 2. Infrastructure as Code with Azure Service Operator
**Question:** "We're migrating from ARM templates to Azure Service Operator for our Infrastructure as Code approach. Can you explain the advantages and potential challenges of this migration? How would you handle secrets management when ASO provisions Azure resources that need to communicate with external services? Walk me through how you'd structure the GitOps workflow for this setup."

*This evaluates their understanding of modern IaC patterns, GitOps, and the specific challenges of managing cloud resources through Kubernetes operators.*

## 3. Istio Service Mesh Troubleshooting
**Question:** "An application team is migrating from a traditional load balancer to our Istio ingress setup, but they're experiencing intermittent 503 errors and increased latency. Their application worked fine before. How would you systematically troubleshoot this issue? What Istio-specific configurations might need adjustment, and what observability tools would you use to diagnose the problem?"

*This tests practical troubleshooting skills with service mesh technology and their ability to help application teams through platform transitions.*

## 4. Node Scheduling and Resource Management
**Question:** "We use Node Autoprovisioner for node scheduling. A team deploys an application that requires GPU nodes, but they're seeing pods stuck in 'Pending' state. Meanwhile, another team complains their CPU-intensive workload is being throttled despite having resource requests set correctly. How would you investigate both issues? What node scheduling concepts and Kubernetes resource management principles are relevant here?"

*This assesses their knowledge of Kubernetes scheduling, resource management, and node-level troubleshooting - important for platform optimization.*

## 5. End-to-End Platform Integration Scenario
**Question:** "A new application team wants to onboard a microservices application that needs: external DNS for custom domains, secrets stored in Azure Key Vault, specific network policies for PCI compliance, and integration with our Istio service mesh. Walk me through the complete onboarding process - what would be automated vs. manual, what potential issues might arise, and how would you ensure the application follows our platform standards while meeting their requirements?"

*This is a comprehensive question that tests their ability to think holistically about platform engineering, combining multiple technologies you mentioned, and their understanding of the balance between automation and customization.*

These questions cover the breadth of your platform while focusing on practical scenarios they'll encounter. They test both technical depth and the ability to work with application teams - which seems to be a key part of the role.