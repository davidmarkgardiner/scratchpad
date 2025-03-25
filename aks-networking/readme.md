# Azure Kubernetes Service (AKS) Networking Best Practices

## Introduction

This README provides a comprehensive guide to networking best practices in Azure Kubernetes Service (AKS). Networking in Kubernetes can be complex, especially when combined with Azure's networking capabilities. This guide breaks down networking decisions into a Kubernetes-centric framework, making it easier to understand and implement the right networking choices for your AKS clusters.

## Table of Contents

1. [Control Plane Networking](#control-plane-networking)
2. [Node Networking](#node-networking)
3. [Pod Networking](#pod-networking)
4. [Application Networking](#application-networking)
5. [Summary](#summary)

## Control Plane Networking

**Key Question**: How do you want to access your API server?

The AKS control plane is a hosted control plane in a Microsoft-managed environment. It runs the API server, controller manager, scheduler, and other core components. Both nodes and end users need to be able to access the API server for updates, configuration changes, and cluster management.

### Options:

#### 1. Public Cluster (Default)
- API server accessible via a public IP address
- Access can be restricted to certain source IP ranges
- Uses connectivity tunnel for node and pod access
- Traffic flow: Kubernetes node pool → Internet → Public endpoint → Cluster API server

```
Kubernetes Node Pool ──→ Internet ──→ Public Endpoint ──→ API Server
```

#### 2. Private Cluster
- Uses Azure Private Link
- API server accessible via an internal IP address
- Uses Azure Private DNS for API server hostname
- Uses connectivity tunnel for node and pod access
- More complex but more secure
- Traffic flow: Kubernetes node pool → Private Link → API Server

```
Kubernetes Node Pool ──→ Private Link ──→ API Server
```

#### 3. API Server VNet Integration (Preview)
- API servers are provisioned into a delegated subnet from your VNet
- May still use connectivity tunnel for pod access
- Keeps traffic within your VNet for better security
- Can add or remove public access without cluster disruption

```
Your VNet
┌─────────────────────────────────────────────┐
│                                             │
│  Kubernetes Node Pool ──→ API Server        │
│                                             │
└─────────────────────────────────────────────┘
```

### Recommendations:
- **General Use**: Public cluster (simplest option)
- **Security/Compliance Requirements**: Private cluster
- **Future Standard** (once GA): API server VNet integration

## Node Networking

**Key Question**: How do you want your cluster to access the internet?

Node networking controls how your AKS nodes access each other, the API server, and the internet.

### VNet Selection:
- **Managed**: Microsoft/AKS owns and manages the VNet and subnet delegation
- **Bring Your Own VNet (BYOVNET)**: You own and manage the VNet

### Cluster Outbound Types:

#### 1. Load Balancer (Default)
- Uses Azure Standard Load Balancer
- Fixed SNAT ports assigned per node on creation
- Traffic flow: Node → Load Balancer → Egress IP → Internet

```
                       ┌───────────────┐
                       │   Internet    │
                       └───────┬───────┘
                               │
                        ┌──────┴───────┐
                        │   Egress IP  │
                        └──────┬───────┘
                               │
                      ┌────────┴────────┐
                      │  Load Balancer  │
                      └────────┬────────┘
                               │
                     ┌─────────┴─────────┐
                     │ Kubernetes Nodes  │
                     └───────────────────┘
```

#### 2. NAT Gateway
- Available in both managed VNet and BYOVNET
- Better SNAT port handling than Load Balancer
- Good for high volume of outbound connections
- Will be zone redundant in the future
- Outbound: Node → NAT Gateway → Egress IP → Internet
- Inbound: Load Balancer → Node

```
                       ┌───────────────┐
                       │   Internet    │
                       └───────┬───────┘
                               │
                        ┌──────┴───────┐
                        │   Egress IP  │
                        └──────┬───────┘
                               │
                      ┌────────┴────────┐
                      │   NAT Gateway   │
                      └────────┬────────┘
                               │
                     ┌─────────┴─────────┐
                     │ Kubernetes Nodes  │
                     └───────────────────┘
```

#### 3. User-Defined Routing (UDR)
- BYOVNET only
- Requires default route to Azure Firewall/VWAN/NVA
- Doesn't typically support external load balancer services directly
- Traffic flow: Node → Route Table → Firewall/Appliance → Egress IP → Internet

```
                       ┌───────────────┐
                       │   Internet    │
                       └───────┬───────┘
                               │
                        ┌──────┴───────┐
                        │   Egress IP  │
                        └──────┬───────┘
                               │
                      ┌────────┴────────┐
                      │Firewall/Appliance│
                      └────────┬────────┘
                               │
                       ┌───────┴───────┐
                       │  Route Table  │
                       └───────┬───────┘
                               │
                     ┌─────────┴─────────┐
                     │ Kubernetes Nodes  │
                     └───────────────────┘
```

### Recommendations:
- **General Use**: Load Balancer
- **High Volume Outbound**: NAT Gateway
- **Custom Security Needs**: User-Defined Routing

## Pod Networking

**Key Question**: Do you need direct pod IP access?

Pod networking controls how pods have IP addresses assigned and defines how pods communicate with each other, cluster nodes, and external destinations. Kubernetes provides pod networking via Container Networking Interface (CNI) plugins.

A CNI plugin has two main components:
1. IP Address Management (IPAM)
2. Routing and Transport (Data Plane)

### IP Address Management (IPAM) Options:

#### 1. Overlay Networking Model (Azure CNI Overlay)
- Pod IPs come from an overlay range (not part of your VNet)
- Most scalable option: up to 5,000 nodes and 250,000 pods
- Can reuse the same pod IP space across all clusters
- Supports dual stack (IPv4/IPv6)
- Pods cannot be accessed directly from outside the cluster
- Traffic leaving pods is SNATed to node IP

```
VNet Space (e.g., 192.168.0.0/16)
┌────────────────────────────────────────┐
│                                        │
│  Node IPs: 192.168.1.0/24              │
│  ┌──────────────────────────────────┐  │
│  │                                  │  │
│  │  Overlay Space (e.g., 10.10.0.0/16) │
│  │  ┌───────────────────────────┐   │  │
│  │  │  Pod IPs: 10.10.1.0/24    │   │  │
│  │  └───────────────────────────┘   │  │
│  │                                  │  │
│  └──────────────────────────────────┘  │
│                                        │
└────────────────────────────────────────┘
```

#### 2. Flat Networking Model (Azure CNI)
Pods can be accessed directly from outside the cluster as they get a VNet IP.

Options include:

##### a. Pod Subnet - Dynamic IP Allocation
- For IP efficiency
- Requires subnet delegation for nodes and pods

##### b. Pod Subnet - Static Block Allocation
- For scale (up to 1 million pod IPs)
- Less efficient IP usage
- Requires subnet delegation

##### c. Node Subnet
- Simplest flat networking option
- No subnet delegation required
- Limited to 64,000 IPs for nodes and pods

```
VNet Space (e.g., 192.168.0.0/16)
┌────────────────────────────────────────────────┐
│                                                │
│  Node Subnet: 192.168.1.0/24                   │
│  ┌──────────────────────────────────────────┐  │
│  │  Node IPs                                │  │
│  └──────────────────────────────────────────┘  │
│                                                │
│  Pod Subnet: 192.168.2.0/24                    │
│  ┌──────────────────────────────────────────┐  │
│  │  Pod IPs                                 │  │
│  └──────────────────────────────────────────┘  │
│                                                │
└────────────────────────────────────────────────┘
```

### Data Plane Options:

#### 1. Azure CNI Powered by Cilium (eBPF)
- More efficient and scalable
- Built-in network policy management
- Supports enhanced network policies (FQDN filtering, L7 coming soon)
- Part of Advanced Container Networking services
- Recommended option

#### 2. Azure Data Plane (IP Tables)
- Less recommended as IP tables may be deprecated
- Requires separate network policy manager installation
- Options include Calico or Azure Network Policy Manager (NPM)
- NPM has severe scale limitations
- Both support Kubernetes spec network policies

#### 3. Bring Your Own CNI
- No managed CNI plugin installed
- CNI-related issues not supported by Microsoft

### Recommendations:
- **General Use**: Azure CNI Overlay with Cilium (most scalable, simple, and efficient)
- **Direct Pod IP Access with Efficiency/Scale**: Azure CNI Pod Subnet (choose Dynamic IP or Static Block based on needs)
- **Direct Pod IP Access with Simplicity**: Azure CNI Node Subnet

## Application Networking

**Key Question**: How do you want to access your applications?

Application networking determines how applications running in your Kubernetes pods are exposed to clients outside the cluster.

### Options:

#### 1. Load Balancer Service (Layer 4)
- Utilizes Kubernetes LoadBalancer service
- Directly exposes applications on public or private IP
- Supports multiple ports and any TCP/UDP traffic
- Requires at least one unique IP:port pair per application

```
                       ┌───────────────┐
                       │    Clients    │
                       └───────┬───────┘
                               │
                               │
                      ┌────────┴────────┐
                      │  Load Balancer  │
                      └────────┬────────┘
                               │
                               │
                    ┌──────────┴──────────┐
                    │  Kubernetes Service │
                    └──────────┬──────────┘
                               │
                               │
                        ┌──────┴───────┐
                        │     Pods     │
                        └──────────────┘
```

#### 2. Ingress Controllers (Layer 7)
- Exposes applications behind a layer 7 reverse proxy
- Only for HTTP-like traffic (HTTP, HTTPS, gRPC)
- Can share a single public IP and ports for all ingress definitions
- Managed options include:
  - NGINX (Application Routing Add-on) - simple but limited capabilities
  - Azure Application Gateway for Containers - many features including Gateway API support
  - Istio Ingress Gateway - compatible with Istio add-on

```
                       ┌───────────────┐
                       │    Clients    │
                       └───────┬───────┘
                               │
                               │
                       ┌───────┴───────┐
                       │    Ingress    │
                       │  Controller   │
                       └───────┬───────┘
                               │
                               │
                    ┌──────────┴──────────┐
                    │  Kubernetes Service │
                    └──────────┬──────────┘
                               │
                               │
                        ┌──────┴───────┐
                        │     Pods     │
                        └──────────────┘
```

### Recommendations:
- **HTTP-like Traffic**: Ingress Controller (choose based on feature needs)
- **Non-HTTP Traffic** (TCP, UDP, SMTP, etc.): Load Balancer Service

## Summary

### Control Plane Networking
- **Question**: How do you want to access your API server?
- **Default/Simple**: Public cluster
- **Security-focused**: Private cluster or API server VNet integration

### Node Networking
- **Question**: How do you want your cluster to access the internet?
- **Default/Simple**: Load Balancer
- **High Outbound Connections**: NAT Gateway
- **Custom Security**: User-Defined Routing

### Pod Networking
- **Question**: Do you need direct pod IP access?
- **Default/Simple/Scalable**: Azure CNI Overlay with Cilium
- **Direct Pod IP Access with Efficiency/Scale**: Azure CNI Pod Subnet
- **Direct Pod IP Access with Simplicity**: Azure CNI Node Subnet

### Application Networking
- **Question**: How do you want to access your applications?
- **HTTP-like Traffic**: Ingress Controller
- **Non-HTTP Traffic**: Load Balancer Service

By following these best practices and answering the key questions for each networking layer, you can create an AKS cluster with the optimal networking configuration for your specific requirements.