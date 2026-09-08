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

### 🚨 Kubeadm Migration & Worker Join Troubleshooting
The following issues were encountered and resolved while moving the lab to kubeadm for CKS exam fidelity and joining the Arch Linux worker:

1. **Wrong tool for the job (design decision):** k3s abstracts away static-pod-manifest editing, which is exactly what the CKS exam tests. Switched to kubeadm for exam fidelity.
2. **Multipass cannot bridge over Wi-Fi:** macOS blocks VM bridging on Wi-Fi interfaces at the OS level (Ethernet only). Fixed with `pf` port forwarding from the Mac's real LAN IP into the VM's private NAT IP.
3. **pf anchor silently inert:** The custom anchor was not referenced by macOS's default `/etc/pf.conf`, which only wires up `com.apple/*`. Fixed by explicitly inserting `rdr-anchor` and `load anchor` lines into `pf.conf`.
4. **`kubeadm join` hanging instead of failing:** A manual SSH join, bypassing Ansible's async wrapper, traced the issue to a genuine `.rc`/`.stderr` bug in the `failed_when` guard. The guard was fixed defensively.
5. **Kubelet/kubeadm version skew:** Arch's pacman supplied `v1.36.3` against a `v1.34.11` control plane; kubeadm refuses a kubelet newer than the control plane. Fixed by pinning exact binaries from `dl.k8s.io` instead of pacman.
6. **Dead upstream URL:** The `kubepkg` template path in `kubernetes/release` was removed entirely upstream. Replaced with static, hand-written systemd unit files.
7. **TLS SAN mismatch:** The API server certificate only had SANs for its internal IPs, not the Mac's forwarded LAN IP that the worker actually dials. Fixed by regenerating the apiserver certificate with `--apiserver-cert-extra-sans`.
8. **Stale `cluster-info` ConfigMap:** Even after the certificate fix, kubeadm pulled an embedded kubeconfig from the `kube-public` ConfigMap pointing at the VM's private IP. Patched that ConfigMap's `server:` field directly.
9. **Stale local join state on Arch:** Failed attempts left a half-written `kubelet.conf` pointing at a certificate that no longer existed, so kubelet could not fall back to bootstrap. Fixed with a full manual wipe, now folded into the playbook as a standing cleanup step.
10. **Swap enabled via zram:** Arch/Omarchy's `zram-generator` kept re-enabling swap, which kubelet refuses to run under. Fixed by masking the `systemd-zram-setup@zram0` unit.

### 🚨 Incident INC-20260908-01: Kubernetes Multi-Node Cluster Network Initialization Failure on macOS Hypervisor
- **Status:** Resolved
- **Severity:** Critical
- **Environment:** macOS Multipass control plane running Ubuntu 22.04 and Kubernetes `v1.34.11`; external Ubuntu 22.04 worker running Kubernetes `v1.34.11`; Calico managed by the Tigera Operator.
- **Symptoms:** The control plane became `KubeletNotReady`; the runtime reported `NetworkPluginNotReady`; Calico pods entered `Init:Error` or `Terminating` loops; and the console reported `cni plugin not initialized`.
- **Root Cause:**
  1. The cluster was initialized without `--pod-network-cidr`, leaving kubeadm configuration without a valid `podSubnet`.
  2. The Tigera Operator could not reconcile the Calico IPPool because the kubeadm configuration was missing `podSubnet`.
  3. The control plane VM was isolated on a private NAT subnet while the external worker was on the physical home Wi-Fi subnet, causing API timeouts during the `install-cni` phase.
- **Resolution:**
  1. Recreated the VM with native Multipass networking so it received a reachable address on the physical LAN.
  2. Reset node state, removed stale CNI and etcd data, and re-initialized kubeadm with `--pod-network-cidr=192.168.0.0/16` and the bridged control-plane address.
  3. Re-applied the Tigera Operator and Calico custom resources, allowing reconciliation against the defined pod subnet.
  4. Reset and re-joined the external worker using a freshly generated kubeadm join command. Tokens and certificate hashes remain outside tracked documentation.
  5. Added a DHCP reservation for the bridged VM interface so router lease changes cannot invalidate the API endpoint.
- **Preventative Actions:** Explicitly declare network configuration, including `--pod-network-cidr`, in future cluster setups; retain a DHCP reservation or static address for the bridged control-plane VM; and generate join commands at execution time rather than recording them in the changelog.

## 🚀 Current Operational Status
- [x] Mac Control Plane Provisioned via Bridged Interface
- [x] Control Plane Core Bootstrapped via Kubeadm (v1.34)
- [x] Multi-Arch Calico Operator Initialized & Pod Network Layer Running
- [x] Codebase Fully Sanitized for Public GitHub Push
- [x] Arch Linux Worker Node Component Integration & Cluster Joining

