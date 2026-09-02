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

The current verified implementation is limited to the Vagrant base environment.

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
- `vagrant halt` is the supported command to stop the environment.

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

- SaltStack automation
- Slurm deployment and scheduling
- K3s cluster setup
- Prometheus monitoring stack
- Grafana dashboard configuration
- Metrics Gateway service

The current repository state demonstrates the Vagrant foundation only; the remaining infrastructure and application layers described in `TASK.md` are still pending.

## 7. AI usage

GitHub Copilot created the initial non-duplicated Vagrantfile structure. That structure was then manually reviewed and functionally tested in the working environment. The resulting configuration was validated through `vagrant validate`, `vagrant up`, `vagrant status`, and direct network connectivity checks.

## 8. Summary

This repository currently contains a verified three-node Ubuntu Vagrant environment with a shared private network and working inter-node connectivity. It does not yet implement the complete distributed HPC + observability architecture described in the assignment, and no claim is made that the full technical assignment is finished.

