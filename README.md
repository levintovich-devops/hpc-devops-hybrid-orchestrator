# HPC DevOps Hybrid Orchestrator

## 1. Project overview

This project is based on the requirements in `TASK.md` and is intended to build a reproducible hybrid HPC and cloud-native observability environment. The target design includes:

- a builder node for compiling and packaging artifacts,
- a controller node for central orchestration services,
- a compute node for execution and Kubernetes-based monitoring,
- a private-network Vagrant topology for multi-node testing,
- later automation with SaltStack, Slurm, K3s, Prometheus, Grafana, and a custom metrics gateway.

The full technical assignment is a future-state design and automation plan, not a completed implementation.

## 2. Current implementation status

The verified implementation includes the Vagrant three-node environment and the current Builder bootstrap progress. It does not claim that Builder or Phase 1 is complete.

Verified facts:

- Vagrant 2.4.9 was installed.
- Three Ubuntu 22.04 VMs were created and are configured on the same private network.
- The node IPs are:
  - builder: 192.168.56.10
  - controller: 192.168.56.11
  - compute: 192.168.56.12
- `vagrant validate` completed successfully.
- `vagrant up` created all three VMs.
- `vagrant status` showed all three machines running.
- Full network connectivity was tested in every direction with zero packet loss.
- `./artifacts` is mounted as `/artifacts` on all three nodes and was tested from builder, controller, and compute.
- `vagrant halt` is the supported command to stop the environment.
- Builder uses Vagrant's built-in Salt provisioner in masterless mode because the builder must configure itself before the controller is started.
- Salt installs the base build packages from Pillar.
- Salt installs Podman.
- Salt creates `/artifacts/slurm-debs` and `/artifacts/images`.
- The initial Builder highstate succeeded with `Succeeded: 4`, `Changed: 4`, and `Failed: 0`.
- The first idempotency rerun exposed the Windows shared-folder permission problem and failed for two directory mode checks.
- After removing `dir_mode`, the final rerun completed with `Succeeded: 4`, `Failed: 0`, and no changes, confirming idempotency.

## 3. Node table

| Name | IP Address | Planned role |
| --- | --- | --- |
| builder | 192.168.56.10 | Build host for artifacts and packaging |
| controller | 192.168.56.11 | Planned Salt master and central orchestration node |
| compute | 192.168.56.12 | Planned execution node and K3s host |

## 4. Prerequisites

Before starting the Vagrant environment, ensure the following are available on the host machine:

- Vagrant 2.4.9 or compatible Vagrant version
- A supported virtualization provider such as VirtualBox
- A working local network environment for private Vagrant networking
- Git for repository management

Install Vagrant on Windows:

```powershell
winget install Hashicorp.Vagrant
vagrant --version
```

## 5. Operational commands

From the repository root:

### Validate the Vagrantfile

```bash
vagrant validate
```

### Builder provisioning

```bash
vagrant up builder
vagrant provision builder
```

### Start the environment

```bash
vagrant up
```

### Check machine state

```bash
vagrant status
```

### Connect to a node over SSH

```bash
vagrant ssh builder
vagrant ssh controller
vagrant ssh compute
```

### Test network connectivity

```bash
vagrant ssh builder -c "ping -c 2 192.168.56.11 && ping -c 2 192.168.56.12"
vagrant ssh controller -c "ping -c 2 192.168.56.10 && ping -c 2 192.168.56.12"
vagrant ssh compute -c "ping -c 2 192.168.56.10 && ping -c 2 192.168.56.11"
```

These checks were performed successfully with zero packet loss in all directions.

### Stop the environment

```bash
vagrant halt
```

## 6. Not implemented yet

The following items are not implemented in the current verified state and should not be interpreted as complete:

- SaltStack automation beyond the verified Builder bootstrap
- Slurm compilation
- Container image build
- Artifact export to the shared folder
- Automatic Builder shutdown
- Controller and compute service orchestration
- K3s cluster setup
- Prometheus monitoring stack
- Grafana dashboard configuration
- Metrics Gateway service

The current repository state demonstrates the Vagrant foundation and verified Builder bootstrap only; the remaining infrastructure and application layers described in `TASK.md` are still pending.

## 7. AI usage

GitHub Copilot generated the Vagrant loop, the Salt State, and the Pillar structure to automate configuration and avoid duplication. The configuration was manually reviewed and tested. The unauthorized external `vagrant-salt` plugin was removed, and malformed JSON configuration and shared-folder permission handling were corrected before acceptance.

## 8. Summary

This repository currently contains a verified three-node Ubuntu Vagrant environment with a shared private network and working inter-node connectivity. It does not yet implement the complete distributed HPC + observability architecture described in the assignment, and no claim is made that the full technical assignment is finished.

