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

Phase 1: Environment & Artifacts is complete and verified.

Verified Phase 1 results:

- Three Ubuntu 22.04 Vagrant nodes exist on a private network with static IPs:
  - builder: 192.168.56.10
  - controller: 192.168.56.11
  - compute: 192.168.56.12
- Controller and Compute are provisioned using Vagrant's built-in Salt provisioner.
- Controller runs Salt Master using `salt/config/controller-master` with `auto_accept` enabled.
- Controller Salt Master was verified active.
- Controller Salt version `3008.2 Argon` was verified.
- Compute runs Salt Minion and receives the Controller IP from the Vagrant machines data structure.
- Compute Salt Minion was verified active.
- Controller successfully received `compute: True` from `salt 'compute' test.ping`.
- Builder installs build dependencies and Podman.
- Builder compiles Slurm 26.05.3 into separate DEB packages.
- Builder exports the Slurm DEBs and the `SHA256SUMS` file to the shared artifacts directory.
- Builder builds and exports the Metrics Gateway image archive.
- Builder stores all artifacts in `/artifacts` and retains them in the shared artifacts directory.
- Builder automatically powers off after successful provisioning.
- Resource allocation is verified as:
  - Builder: 4096 MB RAM, 4 CPUs
  - Controller: 2048 MB RAM, 2 CPUs
  - Compute: 4096 MB RAM, 2 CPUs
- The Controller Slurm daemons, Controller Podman, Compute `slurmd`, and K3s are target node roles identified in Phase 1. Their installation and configuration belong to Phase 2 and Phase 3 as explicitly described in `TASK.md`.
- The verified Slurm build uses parallel compilation across all Builder CPUs with:

```bash
debuild -b -uc -us -j$(nproc)
```

- The verified Slurm artifact directory is:

```text
host: artifacts/slurm-debs/26.05.3
VM: /artifacts/slurm-debs/26.05.3
```

- The verified Metrics Gateway image archive location is:

```text
host: artifacts/images/metrics-gateway-0.1.0.tar
VM: /artifacts/images/metrics-gateway-0.1.0.tar
```

- `PUT /update-metric` returned `200`.
- `GET /metrics` returned valid Prometheus text format.
- Invalid metric names returned `400`.
- Repeated Builder provisioning produced no changes. The SHA256 hash of the Metrics Gateway image archive remained identical before and after the rerun.
- The Builder automatic shutdown was verified and the final VM state was `builder poweroff (virtualbox)`.

## 3. Node table

| Name | IP Address | Current Phase 1 state |
| --- | --- | --- |
| builder | 192.168.56.10 | Artifact build completed; VM automatically powered off |
| controller | 192.168.56.11 | Salt Master; running |
| compute | 192.168.56.12 | Salt Minion; running |

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

## 5. Phase 1 deployment

From the repository root:

```bash
vagrant validate
vagrant up --provision
vagrant status
```

Expected final state:

- builder: poweroff
- controller: running
- compute: running

### Validation commands

```bash
vagrant ssh controller -c "sudo systemctl is-active salt-master"
vagrant ssh compute -c "sudo systemctl is-active salt-minion"
vagrant ssh controller -c "sudo salt 'compute' test.ping"
vagrant ssh controller -c "cd /artifacts/slurm-debs/26.05.3 && sha256sum -c SHA256SUMS"
vagrant ssh controller -c "test -s /artifacts/images/metrics-gateway-0.1.0.tar && echo 'Metrics Gateway image archive: OK'"
```

Expected results:

- Salt Master and Salt Minion return `active`.
- Salt `test.ping` returns `compute: True`.
- Every Slurm DEB checksum returns `OK`.
- The Metrics Gateway image archive check returns `OK`.

`vagrant provision builder` can only be used while Builder is already running.

## 6. Not implemented yet

The following Phase 2 and later work is not implemented and should not be interpreted as complete:

- Controller Podman and Node Exporter
- MariaDB
- synchronized Munge
- Slurm installation and configuration
- slurmctld, slurmdbd, and slurmd
- K3s
- Prometheus and Grafana
- Metrics Gateway Helm deployment
- Phase 5 Slurm reporting job

No later component is claimed as implemented.

## 7. AI usage

GitHub Copilot generated the data-driven Vagrant machine definitions, resource allocation, Salt provisioning configuration, Builder states, Slurm build automation, Metrics Gateway build context, image export workflow, and automatic Builder shutdown trigger. These changes were used to eliminate duplicated configuration, make artifact production reproducible, and ensure that Builder releases its resources after completing the builds. All generated code was manually reviewed and tested. Manual corrections included replacing `trigger.run` with `trigger.run_remote`, removing the unapproved external `vagrant-salt` plugin, fixing malformed Salt JSON configuration, handling Windows shared-folder permissions, deriving repeated values from Pillar, enabling noninteractive and parallel Slurm compilation, validating required DEB packages and checksums, exporting the container image safely through a temporary file, producing valid Prometheus metrics with labels, adding the required `import sys`, and running the Podman image build rootless as the Pillar-defined `vagrant` user after the rootful build failed. Idempotency was verified by rerunning the Salt provisioning and confirming that no unnecessary rebuilds or artifact changes occurred.

## 8. Summary

Phase 1: Environment & Artifacts is complete and verified. The Builder artifact workflow and Controller/Compute Salt provisioning are in place and validated. The remaining work is limited to the Phase 2 and later components described in `TASK.md`.

