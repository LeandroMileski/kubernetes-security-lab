# Irish Payslip Analyzer

**Infrastructure-first local AI platform**

A privacy-first document AI platform running on a heterogeneous Kubernetes cluster built from consumer hardware.

The infrastructure is automated with Ansible and designed to run workloads across ARM64 and x86_64 nodes.  
The application layer — an Irish payslip analyzer — is used as a realistic workload for validating the platform.

---

## Architecture Overview

```
Ansible
  ↓
Provisioning
  ↓
Kubernetes
  ↓
Calico
  ↓
Scheduling
  ↓
Storage
  ↓
Local AI inference
  ↓
Application workloads
```

---

## Hardware Constraints (Worker Node)

| Constraint                  | Details                          |
|----------------------------|----------------------------------|
| Memory                     | ~16 GiB usable RAM               |
| GPU                        | MX350 with only ~2 GiB VRAM      |
| Architecture               | ARM64 + x86_64                   |
| Processing                 | Fully local / private            |
| Inference style            | CPU-heavy                        |
| Scheduling                 | Heterogeneous                    |

---

## Phase 1 — Cluster Bootstrap

```
Ansible
  ↓
Provision machines
  ↓
Install prerequisites
  ↓
Install container runtime
  ↓
Install Kubernetes
  ↓
Initialize control plane
  ↓
Generate / join workers
  ↓
Configure labels & taints
  ↓
Install Calico
  ↓
Verify cluster
```

---

## Phase 2 — Kubernetes Platform

- Namespaces
- NetworkPolicies
- Storage
- Ingress
- Monitoring

---

## Phase 3 — AI Infrastructure

- Ollama
- Qwen3 8B
- Hardware-aware scheduling
- Persistent model storage
- Resource limits

---

## Phase 4 — Application Layer

- PDF parser
- Extraction
- Pydantic models
- Analytics
- API
- Frontend
```
