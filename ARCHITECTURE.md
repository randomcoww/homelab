# Homelab Architecture

This document describes the high-level architecture of the Kubernetes homelab provisioning system.

## Overview

This project is a **Terraform/OpenTofu-based Infrastructure as Code (IaC) provisioner** for a self-hosted Kubernetes homelab. It automates the complete lifecycle of a production-grade, multi-node Kubernetes cluster running on commodity hardware, including host provisioning, cluster bootstrap, and service deployment.

The entire infrastructure is declaratively defined in HCL and follows a modular, layered provisioning strategy.

## Architecture Layers

### 1. **Infrastructure Foundation Layer**

This layer handles cloud resources and external service integrations.

**Directory:** `cloud_resources/`

**Components:**
- **Cloudflare Integration**: DNS, Workers, R2 Storage (backup destination), Zero Trust configuration
- **External APIs**: GitHub, Tailscale, Let's Encrypt credentials management
- **State Management**: Central Terraform state storage for cluster-wide configuration

**Responsibilities:**
- Provision cloud-based resources
- Manage external service accounts and permissions
- Generate shared certificates and credentials
- Store secrets in environment files for downstream provisioning stages

---

### 2. **Host Provisioning Layer**

This layer provisions bare-metal nodes with operating system images and network configuration.

**Directory:** `host_provisioning/`

**Components:**
- **Fedora CoreOS Images**: Immutable OS images built from [fedora-coreos-config-custom](https://github.com/randomcoww/fedora-coreos-config-custom)
- **Ignition Configuration**: Machine-specific hardware setup, network VLAN configuration, storage partitioning
- **Network Configuration**: Multi-network setup including:
  - **LAN** (192.168.192.0/24): Client/user access
  - **Node** (192.168.200.0/24): BGP peering network
  - **Service** (192.168.208.0/24): Kubernetes external service IPs and load balancers
  - **Sync** (192.168.224.0/26): Keepalived state synchronization
  - **Etcd** (192.168.228.0/26): Etcd cluster peering
  - **WAN/Backup**: Dual gateway connectivity with failover
- **Storage Setup**: XFS partitions on NVMe devices for container images

**Hardware Configuration:**
- **4-node cluster** (k-0, k-1, k-2, k-3)
- Roles:
  - k-0, k-1: Gateway + etcd + worker nodes
  - k-2, k-3: Kubernetes control-plane + worker nodes
- Machine-specific MAC addresses, boot parameters, and hardware tweaks

**Responsibilities:**
- Generate machine-specific Ignition files for PXE/netboot
- Configure hardware-specific network interfaces and VLANs
- Prepare boot artifacts on S3 for iPXE provisioning
- Manage SSH credentials and host certificates

---

### 3. **Cluster Bootstrap Layer**

This layer bootstraps low-level Kubernetes infrastructure and storage.

**Directory:** `cluster_bootstrap/`

**Components:**
- **Static Pods**:
  - `kube-apiserver`: Kubernetes API server with dual listen addresses
  - `kube-controller-manager`: Control loop manager
  - `kube-scheduler`: Pod scheduling
  - `etcd`: Distributed key-value store for Kubernetes state
  - `kube-proxy`: Network proxy for service routing
  - `flannel`: Container networking (CNI)
  - `kube-vip`: Virtual IP for API server high availability

- **Storage**:
  - **MinIO**: S3-compatible object storage for FluxCD, application data, and backups
  - Deployed in-cluster with 4 replicas for HA
  - Internal endpoint: `minio.minio.svc.cluster.internal:9000`

- **Networking**:
  - Internal Kubernetes service CIDR: 10.96.0.0/12
  - Pod CIDR: 10.244.0.0/16
  - BGP autonomous system (AS 65005) for routing
  - Keepalived for control-plane high availability

**Responsibilities:**
- Deploy Kubernetes control-plane and worker-node components
- Initialize etcd cluster with peer discovery
- Configure container runtime (CRI-O) and kubelet
- Deploy MinIO for persistent storage
- Setup internal certificate authority for mTLS
- Enable fluxcd-required infrastructure

---

### 4. **Service Resources Layer**

This layer creates application-level resources on the provisioned cluster.

**Directory:** `s3_resources/`

**Components:**
- **MinIO Buckets**: Auto-provisioned based on application requirements
  - `boot`: Public read access for iPXE boot artifacts
  - `registry`: Private registry storage
  - `open-webui`, `stump`, `lldap`, `authelia`: Application data buckets
  - `prometheus`, `fluxcd`: Monitoring and GitOps data

- **MinIO Users & Policies**: Fine-grained S3 access control
  - GitHub Actions Runners (arc): Boot artifact push
  - Internal Registry: Full access
  - Applications: Limited scoped access to specific buckets

- **Local Credentials**: SSH CA certificates, admin kubeconfig, registry credentials
  - Generated for local tooling access
  - Managed as local Terraform state

---

### 5. **Local Credential Management**

**Directory:** `local_credentials/`

**Purpose:** Generate credentials for local operator tooling without storing in shared state.

**Artifacts:**
- SSH user certificates (for SSH CA authentication)
- Admin kubeconfig for kubectl access
- minio/rclone client configurations
- Internal registry client certificates
- LDAP admin passwords
- llama.cpp API keys

---

### 6. **Operations & Maintenance**

**Directory:** `rolling_reboot/`

**Purpose:** Safely reboot cluster nodes with proper workload draining and rescheduling.

---

## Data Flow & Provisioning Order

```
1. cloud_resources (apply)
   ├─ Creates Cloudflare resources
   ├─ Generates shared secrets/credentials.env
   └─ Outputs external service endpoints

2. host_provisioning (apply)
   ├─ Reads cloud_resources outputs
   ├─ Generates Ignition configurations per host
   ├─ Creates S3 boot artifacts (kernel, initramfs, rootfs)
   └─ Creates host SSH credentials

3. cluster_bootstrap (apply)
   ├─ Waits for hosts to boot (Ignition provisioning)
   ├─ Deploys Kubernetes control-plane (static pods)
   ├─ Initializes etcd cluster
   ├─ Deploys flannel CNI
   ├─ Deploys kube-vix for HA
   ├─ Deploys MinIO for S3 storage
   └─ Outputs cluster configuration

4. s3_resources (apply)
   ├─ Creates MinIO buckets
   ├─ Sets up MinIO users with access policies
   └─ Provides application-specific credentials

5. local_credentials (apply, local state)
   ├─ Generates SSH certificates
   ├─ Exports kubeconfig
   └─ Outputs service endpoints for local access
```

## Configuration Model

### Shared Configuration (`config_env.tf`)

Centralized environment configuration inherited across all provisioning stages:

- **Network Topology**: VLAN IDs, CIDR blocks, static IP assignments
- **Container Images**: All OCI image references with SHA256 digests (renovate-managed)
- **Kubernetes Settings**: Cluster name, feature gates, certificate issuers
- **Service Endpoints**: Mapping of services to DNS names, namespaces, ingress paths
- **Port Assignments**: Standardized ports for all cluster services
- **HA Configuration**: keepalived/HAProxy/BIRD paths and BGP AS

### Host Configuration (`config_hosts.tf`)

Per-host hardware and network definitions:

- **Physical Interfaces**: MAC address matching, MTU settings
- **Virtual Interfaces**: VLAN tagging per network
- **Bridge Interfaces**: LAN bridge for multicast
- **Storage**: Disk device paths, partition mount points
- **Boot Parameters**: Kernel arguments for hardware-specific workarounds
- **Role Membership**: Which nodes have which Kubernetes roles

### MinIO Configuration (`config_minio.tf`)

Application-driven MinIO bucket and user provisioning:

- **Static Buckets**: Pre-defined buckets (boot, ebooks, music, fluxcd)
- **User Policies**: Least-privilege S3 IAM policies per application
- **Dynamic Bucket Generation**: Automatically creates buckets referenced in user policies

---

## Key Design Patterns

### 1. **Declarative Configuration**
All infrastructure is version-controlled in HCL. Changes propagate through `tofu apply`.

### 2. **Staged Provisioning**
Clear dependency graph ensures correct order of operations:
- Cloud → Hosts → Cluster → Services → Local tooling

### 3. **State Separation**
- Cloud resources: Shared Terraform state (Cloudflare R2)
- Cluster infrastructure: Shared Terraform state
- Local credentials: Local-only Terraform state (not committed)

### 4. **Immutable Infrastructure**
- Hosts run immutable Fedora CoreOS
- Updates via node reboot with new image versions
- Rolling updates coordinated by Kured

### 5. **High Availability**
- Multi-node etcd cluster
- Virtual IP (kube-vip) for API server
- HAProxy load balancing
- Keepalived for state synchronization
- BGP for network redundancy

### 6. **Self-Hosted Services**
The cluster hosts a complete software stack:
- Container registry (distribution)
- Object storage (MinIO)
- Authentication (LLDAP, Authelia)
- Monitoring (Prometheus, Thanos)
- GitOps (FluxCD)
- DNS (Kea DHCP, k8s-gateway)
- Networking (Flannel CNI, BIRD BGP)

---

## Module Organization

**Directory:** `modules/`

Contains reusable Terraform modules for:
- Host ignition generation
- Kubernetes resource templates
- Network configuration
- Certificate provisioning
- MinIO bucket/user management

---

## External Dependencies

### Required API Tokens & Secrets

**Cloudflare:**
- API token with permissions for R2, Workers, Tunnel, Zone settings, DNS, Zero Trust

**GitHub:**
- Personal access token with `repo`, `workflow` scopes
- Used for Renovate (dependency updates), GHA runners, GitOps bootstrap

**Tailscale:**
- OAuth client credentials with auth_keys, devices, dns, policy_file scopes
- Provides secure access to cluster without exposing services

**Let's Encrypt:**
- Username (for ACME account)
- Used for TLS certificates on public-facing services

**Email (Gmail):**
- SMTP credentials for alerts and notifications

**Scrape Proxy:**
- Optional proxy for metrics scraping from external systems

---

## Service Ecosystem

The cluster runs 50+ containerized services including:

**Tier 1 (Core):**
- Kubernetes components (apiserver, scheduler, controller-manager)
- Networking (kube-proxy, flannel, kube-vip)
- Storage (MinIO, etcd)

**Tier 2 (Infrastructure):**
- Container registry (distribution)
- Network boot (iPXE, KEA DHCP)
- SSH CA server

**Tier 3 (Applications):**
- AI/ML (llama.cpp, Open WebUI)
- Media (Navidrome, Stump ebook server)
- Authentication (LLDAP, Authelia)
- Networking (Tailscale)
- Remote access (Sunshine desktop)
- Search (SearXNG)
- Package management (MCP proxy)

---

## Operational Workflows

### Initial Deployment

```bash
# Setup credentials
source credentials.env

# Deploy cloud resources
tofu -chdir=cloud_resources init && tofu -chdir=cloud_resources apply

# Provision hosts (boots via iPXE)
tofu -chdir=host_provisioning init && tofu -chdir=host_provisioning apply

# Bootstrap Kubernetes cluster
tofu -chdir=cluster_bootstrap init && tofu -chdir=cluster_bootstrap apply

# Provision S3 buckets and users
tofu -chdir=s3_resources init && tofu -chdir=s3_resources apply
```

### Post-Deployment Operations

```bash
# Generate local credentials
tofu -chdir=local_credentials init && tofu -chdir=local_credentials apply

# Access MinIO
source <(tofu -chdir=local_credentials output -json minio | jq ...)

# Access Kubernetes
export KUBECONFIG=$(tofu -chdir=local_credentials output -raw kubeconfig)

# Rolling reboot for kernel updates
tofu -chdir=rolling_reboot init && tofu -chdir=rolling_reboot apply
```

---

## Summary

This homelab represents a **production-grade, fully declarative Kubernetes infrastructure** where every component—from bare metal provisioning to application deployment—is defined as code. The layered architecture ensures clear separation of concerns while maintaining tight integration through Terraform outputs. The system prioritizes **high availability, security, and automation**, making it suitable for both personal infrastructure experimentation and small-scale production workloads.
