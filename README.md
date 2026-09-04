# HPC DevOps Hybrid Orchestrator

## Quick access

Grafana: https://grafana.local

A reproducible three-node HPC lab that combines Vagrant, Salt, Slurm, K3s, Prometheus, Grafana, and a Metrics Gateway for automated job-load reporting.

## Status

Phases 1-5 are complete and verified.

## Architecture

| Node | Address | Role |
| --- | --- | --- |
| Builder | 192.168.56.10 | Temporary artifact builder; powers off after builds |
| Controller | 192.168.56.11 | Salt Master, Slurm controller, database, and job submitter |
| Compute | 192.168.56.12 | Only Salt Minion, Slurm compute node, K3s, Prometheus, and Grafana |

## Prerequisites

- Vagrant
- VirtualBox
- Git

## Deploy

From a clean clone:

```powershell
vagrant up --provision
```

Expected state:

```text
builder     poweroff
controller  running
compute     running
```

## Grafana

Open Windows PowerShell as Administrator and configure the hosts file:

```powershell
$hostsFile = "$env:SystemRoot\System32\drivers\etc\hosts"
if (-not (Select-String -Path $hostsFile -Pattern '^\s*192\.168\.56\.12\s+grafana\.local\s*$' -Quiet)) {
    Add-Content -Path $hostsFile -Value "`r`n192.168.56.12 grafana.local"
}
ipconfig /flushdns
```

Chrome may show a certificate warning for the private lab certificate. Then open [https://grafana.local](https://grafana.local).

From Windows, connect to Compute:

```powershell
vagrant ssh compute
```

Inside Compute, retrieve the Grafana username and password from Kubernetes:

```bash
sudo k3s kubectl get secret monitoring-grafana -n monitoring -o jsonpath='{.data.admin-user}' | base64 -d; echo
sudo k3s kubectl get secret monitoring-grafana -n monitoring -o jsonpath='{.data.admin-password}' | base64 -d; echo
```

Available dashboards:

- **Node Exporter Full**
- **Live Slurm Job Load**

## Stop

```powershell
vagrant halt
```

See [docs/IMPLEMENTATION.md](docs/IMPLEMENTATION.md) for implementation details, validation commands, troubleshooting, and idempotency checks. See [docs/TASK.md](docs/TASK.md) for the project task definition.

## AI usage

GitHub Copilot assisted with implementation and documentation. Human review verified the architecture, automation, security boundaries, and validation guidance.
