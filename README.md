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

The verified implementation includes the Vagrant three-node environment and the Builder Slurm DEB build path. It does not claim that the full Phase 1 workflow is complete.

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
- Builder is configured with 4096 MB RAM and 4 CPUs in the Vagrant machines data structure.
- The original VM had about 1 GB RAM and 2 CPUs.
- Resources were increased to support reliable Slurm source compilation.
- Verification after `vagrant reload` showed 4 CPUs and 3.8 GiB RAM.
- The verified Slurm 26.05.3 DEB build was produced on Builder.
- The Builder Slurm build is run with:

```bash
vagrant provision builder
```

- The build uses parallel compilation across all Builder CPUs with:

```bash
debuild -b -uc -us -j$(nproc)
```

- Generated artifacts are stored in both locations:

```text
host: artifacts/slurm-debs/26.05.3
VM: /artifacts/slurm-debs/26.05.3
```

- The checksum verification command is:

```bash
vagrant ssh builder -c "cd /artifacts/slurm-debs/26.05.3 && sha256sum -c SHA256SUMS"
```

- Every DEB must return `OK` during checksum verification.
- All generated DEBs passed checksum verification.
- The `.complete` marker prevents the Slurm build from being rebuilt unnecessarily.
- The idempotency rerun completed with `Failed: 0` and no changes.
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

- `vagrant up builder` starts the Builder VM and provisions it on the first run.
- `vagrant provision builder` reruns Salt provisioning on an existing Builder VM.

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

### Verify Slurm DEB artifacts

```bash
vagrant ssh builder -c "cd /artifacts/slurm-debs/26.05.3 && sha256sum -c SHA256SUMS"
```

Every DEB must return `OK`.

### Stop the environment

```bash
vagrant halt
```

## 6. Not implemented yet

The following items are not implemented in the current verified state and should not be interpreted as complete:

- Container image build
- Automatic Builder shutdown
- Controller and Compute Salt orchestration
- Slurm installation
- K3s
- Prometheus
- Grafana
- Metrics Gateway

The current repository state demonstrates the Vagrant foundation, verified Builder bootstrap, and verified Slurm 26.05.3 DEB packaging on Builder. The remaining infrastructure and application layers described in `TASK.md` are still pending.

## 7. AI usage

GitHub Copilot generated the data-driven Vagrant machine loop and Builder resource configuration. It also generated the Pillar values, Salt state, and Bash build script to download, verify, compile, and export separate Slurm DEBs. The Slurm automation was used to make source compilation reproducible, validate package integrity, export reusable DEBs, and avoid unnecessary rebuilds. The output was manually reviewed and corrected for version deduplication, noninteractive dependency installation, parallel compilation, required-package validation, checksums, and idempotency. The unauthorized external `vagrant-salt` plugin was removed, and malformed JSON configuration and shared-folder permission handling were corrected before acceptance.

## 8. Summary

This repository currently contains a verified three-node Ubuntu Vagrant environment with a shared private network and working inter-node connectivity. It does not yet implement the complete distributed HPC + observability architecture described in the assignment, and no claim is made that the full technical assignment is finished.

