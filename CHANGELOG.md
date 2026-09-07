# 🛠️ Infrastructure & Engineering Log: Cross-Laptop Mixed-Architecture Cluster

This log tracks the architecture decisions, network debugging, and security configurations implemented while building a multi-node Kubernetes 1.34 lab spanning an **Apple Silicon M4 Mac (Control Plane)** and an **Intel x86_64 Arch Linux Laptop (Worker Node)**.

---

## 📋 Architecture & Constraints Overview
- **Control Plane:** Ubuntu 22.04 VM managed via Multipass on macOS (ARM64 / Apple M4).
- **Worker Node:** Bare-metal Arch Linux (x86_64 / Intel i7-1165G7 / btrfs).
- **Networking Framework:** Calico CNI (for CKS-compliant Network Policy Enforcement).
- **Security Rule:** 100% Sanitized Codebase. Zero plaintext IPs or credentials allowed in Git tracking.

---

## ⚡ Incident Registry & Engineering Solutions

### 🚨 Incident 1: Worker Node Network Blindness (VM Isolation)
- **Symptom:** Multipass default provisioning assigns instances an isolated host-only NAT network (`10.x.x.x`). The M4 VM could reach the internet, but the physical Arch Linux laptop could not route packets to the control plane.
- **Root Cause:** Hypervisor network isolation blocking external physical subnet discovery.
- **Engineering Solution:** Appended the `--network en0` argument directly into the Ansible `multipass launch` task execution. This bridges the control plane directly onto the Mac's physical Wi-Fi interface, assigning it a real local IP (`192.168.1.184`) issued directly by the home router.

### 🚨 Incident 2: Host Firewall Legacy Conflict
- **Symptom:** A custom macOS packet filter script (`pfctl`) was previously mapping ports `6443` and `10250` from the Mac host to the isolated NAT space. Keeping it active on a bridged configuration caused intermittent asymmetric routing loops.
- **Root Cause:** Redundant port forwarding intercepting traffic intended for the new direct bridge IP.
- **Engineering Solution:** Decommissioned the script completely. Reverted the macOS host firewall configuration (`/etc/pf.conf`) to its clean, original factory state and disabled host-level IP forwarding.

### 🚨 Incident 3: Credentials Leakage Risk on Public Repositories
- **Symptom:** Managing connection configs required keeping host inventory profiles populated with physical IPs, Arch target login usernames, and cleartext sudo credentials.
- **Root Cause:** Storing operational metadata in cleartext within git-tracked inventory structures (`hosts.ini`).
- **Engineering Solution:** 
  1. Implemented **Ansible Vault** to isolate all raw environment vectors.
  2. Extracted secrets out to an encrypted variable structure file (`group_vars/arch_laptop/vault.yaml`).
  3. Mapped `ansible_host` to dynamic Jinja2 evaluation placeholders (`"{{ arch_laptop_ip }}"`).
  4. Patched `.gitignore` to prevent any structural `.bak` engine modifications or temporary join tokens (`join_command.txt`) from ever tracking online.

### 🚨 Incident 4: Calico Operator Deployment DNS Failure
- **Symptom:** During control plane post-initialization, the playbook task `Apply standard Tigera Calico Operator` stalled out with a fatal connection lookup failure: `dial tcp: lookup githubusercontent.com on 1.1.1.1:53: no such host`.
- **Root Cause:** A syntax concatenation glitch. An unquoted/malformed Ansible string variable loop (`{{ calico_version }}`) broke the string interpolation path, resulting in an unparseable domain request.
- **Engineering Solution:** Bypassed the string parsing lookup loop by hardcoding the precise, fully-qualified web path tracking literal (`https://githubusercontent.com...`) directly to the executable block arguments.

---

## 🚀 Current Operational Status
- [x] Mac Control Plane Provisioned via Bridged Interface
- [x] Control Plane Core Bootstrapped via Kubeadm (v1.34)
- [x] Multi-Arch Calico Operator Initialized & Pod Network Layer Running
- [x] Codebase Fully Sanitized for Public GitHub Push
- [ ] Arch Linux Worker Node Component Integration & Cluster Joining
