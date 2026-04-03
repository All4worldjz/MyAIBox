# Gemini Context: KSC AIBox

This document provides essential context for Gemini to assist with the KSC AIBox (金山政务AI一体机) project.

## Project Overview

KSC AIBox is an automated deployment and configuration solution for a government AI all-in-one machine. It is designed for "out-of-the-box" readiness, leveraging Ansible to manage a complex stack of hardware (Huawei Kunpeng CPU + Ascend 910B NPU) and software (openEuler 24.03).

### Key Technologies
- **Orchestration:** Ansible 2.x
- **OS:** openEuler 24.03 LTS-SP1 (ARM64/aarch64)
- **Hardware:** Huawei Kunpeng 920 CPU (64 cores), Huawei Ascend 910B NPU (4x 64GB HBM)
- **Containerization:** Docker 18.09, K3s (planned)
- **AI Infrastructure:** vLLM, Huawei MindSpore/CANN (implied by NPU)
- **Optimization:** HugePages (240GB), Kernel tuning, NPU NUMA binding

### Core Architecture
The deployment follows a phased approach, transforming a raw openEuler server into a production-ready AI appliance. All application data, models, and container runtimes are consolidated under the `/ksc_aibox` partition for better management and isolation.

## Project Structure

- `ansible/`: Core automation logic.
  - `playbooks/`: Sequential deployment stages (01-05).
  - `roles/`: Modular components (Docker, K3s, vLLM, etc.).
  - `inventory/hosts`: Target server definitions.
  - `group_vars/all.yml`: Global configuration (paths, ports, versions).
- `docs/`: Comprehensive documentation.
  - `handoff.md`: Project status, hardware specs, and detailed configuration.
  - `Agent.md`: Specific instructions for AI collaboration.
  - `NPU-DRIVER-INSTALLATION.md`: Technical guide for NPU setup.
- `scripts/`: Local and remote utility scripts.
  - `deploy.sh`: Primary entry point for deployment.
- `drivers/`: Vendor-supplied driver packages for NPU 910B.

## Building and Running

### Prerequisites
- **Control Machine:** macOS/Linux with Python 3.11+ and Ansible 2.x installed.
- **Target Machine:** openEuler 24.03 SP1 (ARM64) with SSH access.
- **SSH:** Passwordless SSH configured (`root@10.212.128.192`).

### Deployment Commands
The main entry point is the `scripts/deploy.sh` wrapper script.

```bash
# Execute specific stages
./scripts/deploy.sh 01  # Directory structure
./scripts/deploy.sh 02  # Data migration
./scripts/deploy.sh 03  # System optimization
./scripts/deploy.sh 04  # Health checks & best practices

# Execute full deployment
./scripts/deploy.sh all

# List all available playbooks
./scripts/deploy.sh -l
```

### Manual Ansible Execution
```bash
cd ansible
ansible-playbook -i inventory/hosts playbooks/<name>.yml
```

## Development Conventions

- **Infrastructure as Code:** All configurations must be defined in `ansible/group_vars/all.yml` rather than hardcoded in playbooks.
- **Pathing:** Always use the `/ksc_aibox` root for application-related data. Subdirectories (apps, models, data, logs) are defined in `all.yml`.
- **Target OS:** Assume `aarch64` architecture and `openEuler` specific package managers (`dnf`).
- **SELinux:** Defaults to `Enforcing`. Changes must account for SELinux contexts.
- **Verification:** Every stage has a corresponding verification step (e.g., `npu-smi info`, `hugepages` check).
- **AI Interaction:** Refer to `docs/Agent.md` for guidelines on how this project expects AI assistance.

## Critical Paths & Files

- **Global Config:** `ansible/group_vars/all.yml`
- **Main Entry:** `scripts/deploy.sh`
- **Hardware Specs:** `docs/handoff.md`
- **Target Partition:** `/ksc_aibox` (361GB available)
- **Model Storage:** `/ksc_aibox/models` (333GB used)

## Known Issues / Status

- **vLLM:** Container exists but has configuration errors (Stage 7).
- **K3s & Databases:** Planned but not yet installed (Stage 6).
- **NPU NUMA:** Optimization is active; avoid cross-NUMA NPU usage for performance.
